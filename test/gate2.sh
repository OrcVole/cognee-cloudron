#!/usr/bin/env bash
#
# gate2.sh: auth and functional flows against a LIVE install (gates 1 and 2 of the ladder).
#
#   BASE=https://cognee.example.com EMAIL=admin@example.com PASSWORD=... test/gate2.sh
#
# It never calls the platform's CLI, so it cannot touch another app. It sends the administrator's
# password only to the install under test, never prints it, and removes the dataset and key it creates.
# Needs outbound internet on the install the first time (the local models download on first use).
#
# What it proves, in order:
#   refused: wrong password (400), a missing credential (401), a made-up API key (401), self-registration (403),
#            the four interface routes that would otherwise answer for anonymous callers (401);
#   open:    /health, /docs and the sign-in page need no credentials;
#   works:   sign-in, three documents added, cognify with no language model, a chunk search that finds them,
#            an API key that works and is then revoked.

set -uo pipefail
: "${BASE:?set BASE}"; : "${EMAIL:?set EMAIL}"; : "${PASSWORD:?set PASSWORD}"
BASE=${BASE%/}; PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); echo "PASS  $*"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL  $*"; }
code() { curl -s -o /dev/null -w '%{http_code}' -m 60 "$@"; }
J='Content-Type: application/json'

# ---- open paths ----
[ "$(code "$BASE/health")" = 200 ] && ok "/health answers without credentials" || bad "/health does not answer"
[ "$(code "$BASE/docs")" = 200 ] && ok "/docs answers without credentials" || bad "/docs does not answer"
[ "$(code "$BASE/local-login")" = 200 ] && ok "the sign-in page answers without credentials" || bad "the sign-in page does not answer"

# ---- refused ----
[ "$(code -X POST --data-urlencode "username=$EMAIL" --data-urlencode "password=not-the-password" "$BASE/api/v1/auth/login")" = 400 ] && ok "a wrong password is refused (400)" || bad "a wrong password was not refused"
[ "$(code -X POST -H "$J" -d '{"query":"x","searchType":"CHUNKS"}' "$BASE/api/v1/search")" = 401 ] && ok "no credential is refused (401)" || bad "no credential was not refused"
[ "$(code -X POST -H "X-Api-Key: not-a-real-key" -H "$J" -d '{"query":"x","searchType":"CHUNKS"}' "$BASE/api/v1/search")" = 401 ] && ok "a made-up API key is refused (401)" || bad "a made-up API key was not refused"
[ "$(code -X POST -H "$J" -d '{"email":"intruder@example.com","password":"Password123!"}' "$BASE/api/v1/auth/register")" = 403 ] && ok "self-registration is refused (403)" || bad "self-registration was not refused"
for p in /api/visualize /api/schema/inventory /api/schema/provenance /api/schema-provenance; do
    [ "$(code "$BASE$p")" = 401 ] && ok "anonymous $p is refused (401)" || bad "anonymous $p was not refused"
done

# ---- works ----
TOKEN=$(curl -s -m 60 -X POST --data-urlencode "username=$EMAIL" --data-urlencode "password=$PASSWORD" "$BASE/api/v1/auth/login" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
[ -n "$TOKEN" ] && ok "the administrator signs in" || { bad "the administrator cannot sign in"; echo "gate2: $PASS passed, $FAIL failed"; exit 1; }
H="Authorization: Bearer $TOKEN"; DS=gate2-$$
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
printf '%s\n' "Ada Lovelace wrote the first published algorithm for Charles Babbage's Analytical Engine." > "$T/1.txt"
printf '%s\n' "The Analytical Engine was a proposed mechanical general-purpose computer designed by Charles Babbage." > "$T/2.txt"
printf '%s\n' "Grace Hopper developed the first compiler and popularised machine-independent programming languages." > "$T/3.txt"
ADDED=0; c=$(code -X POST -H "$H" -F "data=@$T/1.txt;type=text/plain" -F "data=@$T/2.txt;type=text/plain" -F "data=@$T/3.txt;type=text/plain" -F datasetName="$DS" "$BASE/api/v1/add")
[ "$c" = 200 ] && { ADDED=1; ok "three documents added"; } || bad "adding documents failed ($c)"
t0=$(date +%s); c=$(code -m 3000 -X POST -H "$H" -H "$J" -d "{\"datasets\":[\"$DS\"]}" "$BASE/api/v1/cognify")
[ "$c" = 200 ] && [ "$ADDED" = 1 ] && ok "cognify completed with no language model ($(( $(date +%s) - t0 )) s)" || bad "cognify returned $c"
hits=$(curl -s -m 300 -X POST -H "$H" -H "$J" -d "{\"searchType\":\"CHUNKS\",\"query\":\"Who designed the Analytical Engine?\",\"datasets\":[\"$DS\"]}" "$BASE/api/v1/search")
echo "$hits" | grep -q 'Babbage' && ok "a chunk search finds the documents" || bad "a chunk search found nothing: ${hits:0:160}"

KEYJSON=$(curl -s -m 60 -X POST -H "$H" -H "$J" -d '{"name":"gate2-temporary"}' "$BASE/api/v1/auth/api-keys")
KEY=$(echo "$KEYJSON" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("key",""))' 2>/dev/null); KID=$(echo "$KEYJSON" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
[ -n "$KEY" ] && ok "an API key is issued" || bad "no API key was issued"
[ "$(code -H "X-Api-Key: $KEY" "$BASE/api/v1/datasets")" = 200 ] && ok "the API key works" || bad "the API key does not work"
[ -n "$KID" ] && [ "$(code -X DELETE -H "$H" "$BASE/api/v1/auth/api-keys/$KID")" = 200 ] && ok "the temporary API key is revoked" || bad "the temporary API key was not revoked"
[ "$(code -H "X-Api-Key: $KEY" "$BASE/api/v1/datasets")" = 401 ] && ok "the revoked key is refused (401)" || bad "the revoked key still works"
DSID=$(curl -s -m 60 -H "$H" "$BASE/api/v1/datasets" | python3 -c "import sys,json; print(next((d['id'] for d in json.load(sys.stdin) if d['name']=='$DS'), ''))" 2>/dev/null)
[ -n "$DSID" ] && [ "$(code -X DELETE -H "$H" "$BASE/api/v1/datasets/$DSID")" = 200 ] && ok "the test dataset is removed" || bad "the test dataset was not removed"

echo; echo "gate2: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

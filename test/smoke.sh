#!/usr/bin/env bash
#
# smoke.sh: prove a built image starts, is closed where it must be, and does its job.
#
#   test/smoke.sh <image>        exit 0 only if every check passes
#
# Runs the image the way the platform does: read-only root filesystem, writable /app/data, /tmp and
# /run, a real PostgreSQL, and the platform's database variables. Then, in order:
#   health answers 200 on /health and NOT on a wrong path (a check that cannot fail is not a check);
#   self-registration is refused (403); the four interface routes that would otherwise sign in as the
#   administrator refuse an anonymous request (401); the administrator signs in with the generated
#   password, and a wrong password is refused; three documents are added, cognify runs with no language
#   model (the local extraction and embedding models download on first use), and a search finds them;
#   nothing was installed at runtime; after a restart the secrets are unchanged and the old session works.
# Needs podman and network access (the models download from Hugging Face on first use).

set -uo pipefail
IMG=${1:?usage: test/smoke.sh <image>}
ID=cognee-smoke-$$; NET=$ID; PORT=${SMOKE_PORT:-18080}; DOMAIN=cognee.example.com
B="http://127.0.0.1:$PORT"; PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); echo "PASS  $*"; }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL  $*"; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
cleanup() { podman rm -f "$ID" "$ID-pg" >/dev/null 2>&1; podman volume rm -f "$ID-data" "$ID-models" >/dev/null 2>&1; podman network rm -f "$NET" >/dev/null 2>&1; }
trap cleanup EXIT

podman network create "$NET" >/dev/null
podman volume create "$ID-data" >/dev/null
podman volume create "$ID-models" >/dev/null   # the platform bind-mounts persistentDirs; the root is read-only
podman run -d --name "$ID-pg" --network "$NET" --network-alias pg \
    -e POSTGRES_USER=cognee -e POSTGRES_PASSWORD=smokepass -e POSTGRES_DB=cognee \
    "${SMOKE_PG_IMAGE:-docker.io/library/postgres:16}" >/dev/null
for _ in $(seq 1 30); do podman exec "$ID-pg" pg_isready -U cognee >/dev/null 2>&1 && break; sleep 2; done

start_app() {
    podman run -d --name "$ID" --network "$NET" --read-only --tmpfs /tmp --tmpfs /run \
        -v "$ID-data":/app/data -v "$ID-models":/app/models -p "127.0.0.1:$PORT:8080" \
        -e CLOUDRON_APP_DOMAIN=$DOMAIN -e CLOUDRON_APP_ORIGIN=https://$DOMAIN \
        -e CLOUDRON_POSTGRESQL_HOST=pg -e CLOUDRON_POSTGRESQL_PORT=5432 \
        -e CLOUDRON_POSTGRESQL_USERNAME=cognee -e CLOUDRON_POSTGRESQL_PASSWORD=smokepass \
        -e CLOUDRON_POSTGRESQL_DATABASE=cognee \
        -e CLOUDRON_POSTGRESQL_URL=postgres://cognee:smokepass@pg:5432/cognee \
        "$IMG" >/dev/null
    for _ in $(seq 1 90); do [ "$(code "$B/health")" = 200 ] && return 0; sleep 4; done
    return 1
}

if start_app; then ok "health 200 within 6 minutes of start"; else bad "health never answered 200"; podman logs --tail 60 "$ID"; exit 1; fi
[ "$(code "$B/health-wrong-path")" != 200 ] && ok "a wrong path is not 200" || bad "a wrong path answered 200"
[ "$(code -X POST -H 'Content-Type: application/json' -d '{"email":"x@example.com","password":"Password123!"}' "$B/api/v1/auth/register")" = 403 ] \
    && ok "self-registration refused (403)" || bad "self-registration was not refused"
for p in /api/visualize /api/schema/inventory /api/schema/provenance /api/schema-provenance; do
    [ "$(code "$B$p")" = 401 ] && ok "anonymous $p refused (401)" || bad "anonymous $p not refused"
done
[ "$(code "$B/")" = 200 ] && ok "the interface answers at /" || bad "the interface does not answer at /"
# The interface refuses its own server actions when the Host it sees differs from the Origin the browser
# sends. nginx's $host drops the port, so any non-standard port broke sign-in follow-ups (found by a local
# run on :8100; Cloudron's 443 hides it). Send a server action whose Origin carries a port; the interface
# logs "does not match `origin`" only when the proxy lost the port.
# A made-up action ID is NOT enough: Next only compares Host and Origin for a real action, so a fake one
# passes on a broken proxy (the first version of this check did exactly that). Take a real ID from the
# built interface.
AID=$(for a in $(curl -s "$B/" | grep -oE '/_next/static/[^"]+\.js' | sort -u); do curl -s "$B$a"; done \
    | grep -oE '"00[0-9a-f]{40}"' | head -1 | tr -d '"')
[ -n "$AID" ] && ok "found a real server action ID in the interface" || bad "no server action ID found"
curl -s -o /dev/null -X POST -H 'Host: probe.example:8123' -H 'Origin: http://probe.example:8123' \
    -H "Next-Action: $AID" -H 'Content-Type: text/plain;charset=UTF-8' -d '[]' "$B/"
sleep 1
podman logs "$ID" 2>&1 | grep -q 'does not match `origin`' \
    && bad "the proxy dropped the port: the interface rejects its server actions on a non-standard port" \
    || ok "the proxy keeps the port in Host (server actions accepted on a non-standard port)"

ADMIN=$(podman exec "$ID" cat /app/data/admin-email)
PW=$(podman exec "$ID" sh -c '. /app/data/.secrets/env; printf %s "$DEFAULT_USER_PASSWORD"')
[ "$ADMIN" = "admin@$DOMAIN" ] && ok "admin address defaults to admin@<app domain>" || bad "admin address is '$ADMIN'"
[ "$(code -X POST -d "username=$ADMIN&password=wrong-password" "$B/api/v1/auth/login")" = 400 ] && ok "wrong password refused" || bad "wrong password not refused"
TOKEN=$(curl -s -X POST --data-urlencode "username=$ADMIN" --data-urlencode "password=$PW" "$B/api/v1/auth/login" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
[ -n "$TOKEN" ] && ok "administrator signs in with the generated password" || { bad "administrator cannot sign in"; exit 1; }
H="Authorization: Bearer $TOKEN"

docs=("Ada Lovelace wrote the first published algorithm for Charles Babbage's Analytical Engine."
      "The Analytical Engine was a proposed mechanical general-purpose computer designed by Charles Babbage."
      "Grace Hopper developed the first compiler and popularised machine-independent programming languages.")
args=(); for i in 0 1 2; do printf '%s\n' "${docs[$i]}" > "/tmp/$ID-$i.txt"; args+=(-F "data=@/tmp/$ID-$i.txt;type=text/plain"); done
ADDED=0; c=$(curl -s -o /tmp/$ID-add.json -w '%{http_code}' -X POST -H "$H" "${args[@]}" -F datasetName=smoke "$B/api/v1/add")
[ "$c" = 200 ] && { ADDED=1; ok "three documents added"; } || bad "adding documents failed ($c): $(head -c 200 /tmp/$ID-add.json)"
# A server path sent as data must never be READ. The status code cannot tell reading the file from
# storing the string as text (both return 200), so check the store for the file's content instead.
code -X POST -H "$H" -F raw_data=/etc/passwd -F datasetName=probe "$B/api/v1/add" >/dev/null
podman exec "$ID" sh -c '! grep -rqs "root:x:0:0" /app/data/data /app/data/system' \
    && ok "a server path sent as data is not read into the store" || bad "server file content reached the store"
rm -f /tmp/$ID-*.txt /tmp/$ID-add.json
c=$(code -m 2400 -X POST -H "$H" -H 'Content-Type: application/json' -d '{"datasets":["smoke"]}' "$B/api/v1/cognify")
# A cognify of an empty dataset also returns 200, so it only counts if the documents were added.
[ "$c" = 200 ] && [ "$ADDED" = 1 ] && ok "cognify completed with no language model" || { bad "cognify returned $c (documents added: $ADDED)"; podman logs --tail 80 "$ID"; }
hits=$(curl -s -m 300 -X POST -H "$H" -H 'Content-Type: application/json' \
    -d '{"searchType":"CHUNKS","query":"Who designed the Analytical Engine?","datasets":["smoke"]}' "$B/api/v1/search")
echo "$hits" | grep -q 'Babbage' && ok "search finds the documents" || bad "search found nothing: ${hits:0:200}"
podman logs "$ID" 2>&1 | grep -qiE 'pip install|uv pip install|GlinerInstallError|installing the gliner' \
    && bad "something was installed at runtime" || ok "nothing installed at runtime"
# start.sh creates both directories empty, so require files in each, not the directories.
podman exec "$ID" sh -c '[ -n "$(find /app/models/huggingface -type f | head -1)" ] && [ -n "$(find /app/models/fastembed -type f | head -1)" ]' \
    && ok "model files cached under /app/models (a persistent directory, out of backups)" || bad "no model files under /app/models"

NEWADMIN=renamed-admin@example.com
podman exec "$ID" /app/code/set-admin-email.sh "$NEWADMIN" >/dev/null 2>&1 && ok "set-admin-email.sh ran" || bad "set-admin-email.sh failed"
for _ in $(seq 1 60); do [ "$(code "$B/health")" = 200 ] && break; sleep 3; done
[ "$(podman exec "$ID" cat /app/data/admin-email)" = "$NEWADMIN" ] && ok "stored admin address renamed" || bad "stored admin address not renamed"
[ "$(code -X POST --data-urlencode "username=$NEWADMIN" --data-urlencode "password=$PW" "$B/api/v1/auth/login")" = 200 ] \
    && ok "administrator signs in with the new address" || bad "new address cannot sign in"
[ "$(code -X POST --data-urlencode "username=$ADMIN" --data-urlencode "password=$PW" "$B/api/v1/auth/login")" = 400 ] \
    && ok "the old address no longer signs in (no second admin)" || bad "the old address still signs in"

S1=$(podman exec "$ID" sha256sum /app/data/.secrets/env)
podman rm -f "$ID" >/dev/null
if start_app; then ok "restarted on the same /app/data"; else bad "did not come back after restart"; exit 1; fi
[ "$S1" = "$(podman exec "$ID" sha256sum /app/data/.secrets/env)" ] && ok "secrets unchanged across restart" || bad "secrets changed on restart"
[ "$(code -H "$H" "$B/api/v1/datasets")" = 200 ] && ok "a session from before the restart still works" || bad "the old session no longer works"

echo; echo "smoke: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

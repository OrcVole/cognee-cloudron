#!/bin/bash
set -eu

if [ $# -ne 1 ]; then
    echo "Usage: set-admin-email.sh <email>"
    exit 1
fi

new="$1"

if [[ "$new" == *"'"* ]]; then
    echo "Error: email cannot contain a single quote."
    exit 1
fi

new=$(echo "$new" | tr '[:upper:]' '[:lower:]')

re='^[^@ ]+@[^@ ]+[.][^@ ]+$'
if ! [[ $new =~ $re ]]; then
    echo "Usage: set-admin-email.sh <email>"
    exit 1
fi

old=$(cat /app/data/admin-email)

if [ "$old" = "$new" ]; then
    echo "already set"
    exit 0
fi

count=$(psql "$CLOUDRON_POSTGRESQL_URL" -v ON_ERROR_STOP=1 -tA -c "SELECT count(*) FROM users WHERE email = '$new'")
if [ "$count" != "0" ]; then
    echo "Error: account with new address already exists."
    exit 1
fi

result=$(psql "$CLOUDRON_POSTGRESQL_URL" -v ON_ERROR_STOP=1 -tA -c "UPDATE users SET email = '$new' WHERE email = '$old'")
if [ "$result" != "UPDATE 1" ]; then
    echo "Error: database update failed."
    exit 1
fi

echo "$new" > /app/data/admin-email
chown cloudron:cloudron /app/data/admin-email

supervisorctl -c /app/code/supervisord.conf restart backend

echo "$new"

#!/bin/sh

set -eu

echo "Reading secrets"
for secret in drive-password
do

    if [ -f /run/secrets/$secret ]
    then
        varname=$(echo $secret | sed 's/.*-//' | tr a-z A-Z) # drive-password -> PASSWORD
        echo "[entrypoint] exposing ${secret} secret as ${varname}"
        export $varname=$(cat /run/secrets/$secret)
    fi
done

echo "Configure 'admin' credentials"
rm -f .users.json
./admin user-add --username "admin" --password "$PASSWORD" || true

echo "Start the server..."
exec node /app/server.js /data

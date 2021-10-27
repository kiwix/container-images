#!/bin/sh

set -eu

echo "Create /data directory if necessary"
mkdir /data

echo "Configure 'admin' credentials"
./admin user-add --username "admin" --password "$PASSWORD" || true

echo "Start the server..."
exec node /app/server.js /data

#!/bin/sh

set -eu

mkdir /data

echo "=> Start the server"
exec node /app/server.js /data

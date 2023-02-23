#!/bin/sh

set -e

echo "Building whitelist…"
/etc/cron.hourly/build-whitelist

echo "Starting cron..."
service cron start

echo "Starting opentracker…"
exec "$@"

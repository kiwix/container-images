#!/bin/sh

set -e

echo "Building whitelist…"
/etc/cron.hourly/build_whitelist.sh

echo "Starting cron..."
service cron start

echo "Starting opentracker…"
exec "$@"

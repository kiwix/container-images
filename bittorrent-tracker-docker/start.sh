#!/bin/sh

set -e

echo "Starting cron..."
service cron start

echo "Starting opentracker..."
opentracker -f /etc/opentracker/opentracker.conf

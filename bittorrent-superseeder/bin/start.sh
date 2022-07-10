#!/bin/bash

QBITTORRENT_PORT=$1

echo "Update crontab for ZIM synchronisation"
printf "
@reboot root /usr/local/bin/sync_superseeder.sh ${QBITTORRENT_PORT} >> /var/log/sync_superseeder.log
0 * * * * root /usr/local/bin/sync_superseeder.sh ${QBITTORRENT_PORT} >> /var/log/sync_superseeder.log
" > /etc/crontab

service cron start

echo "Listening to cron logs..."
sleep 2
tail -f /var/log/sync_superseeder.log

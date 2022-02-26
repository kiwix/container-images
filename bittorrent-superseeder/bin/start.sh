#!/bin/bash

echo "Update crontab for ZIM synchronisation"
printf "
@reboot root /usr/local/bin/bin/sync_superseeder.sh >> /var/log/sync_superseeder.log
0 * * * * root /usr/local/bin/bin/sync_superseeder.sh >> /var/log/sync_superseeder.log
" >> /etc/crontab

service cron start && crontab /etc/crontab

echo "Listening to cron logs..."
tail -f /var/log/sync_superseeder.log

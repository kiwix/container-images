#!/bin/bash

echo "Initializing logger container"

if [ -f /var/run/secrets/matomo-token ]
then
    echo " .. reading matomo secret"
    export MATOMO_TOKEN=$(cat /var/run/secrets/matomo-token)
fi

echo " .. dumping envs to default"
printf "
MATOMO_URL=$MATOMO_URL
MATOKO_SITE_ID=$MATOKO_SITE_ID
MATOMO_TOKEN=$MATOMO_TOKEN
LOG_FOLDER=$LOG_FOLDER
FQDN=$FQDN
NGINX_CONTAINER=$NGINX_CONTAINER
" > /etc/default/logger

echo " .. creting rotated folder"
mkdir -p $LOG_FOLDER/rotated

echo " .. changing perms for logrotate"
chown root /etc/logrotate.d/logger
chown root:root $LOG_FOLDER

echo " .. registering crontab"
chown root:root /etc/crontab
crontab /etc/crontab

echo " done."

exec "$@"

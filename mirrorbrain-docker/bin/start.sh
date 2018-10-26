#!/bin/sh
if [ ! -z $INIT ]
then
  init_mirrorbrain_db.sh
fi

if [ ! -z $UPDATE_DB ]
then
  echo "Install Cron to update DB"
  ln -s /usr/local/bin/update_mirrorbrain_db.sh /etc/cron.hourly/update_mirrorbrain_db.sh
fi

if [ ! -z $UPDATE_HASH ]
then
  echo "Install Cron to update hash"
  ln -s /usr/local/bin/hash_mirrorbrain_db.sh /etc/cron.hourly/hash_mirrorbrain_db.sh
fi

if [ ! -z $HTTPD ]
then
  service cron start
  echo "Start HTTPD ..."
  httpd-foreground -D
else
  if [ ! -z $UPDATE_HASH ] ||  [ ! -z $UPDATE_DB ]
  then
    echo "Start Cron ..."
    cron -f
  fi
fi

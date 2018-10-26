#!/bin/sh
if [ -n $INIT ]
then
  init_mirrorbrain_db.sh
fi

if [ -n $UPDATE_DB ]
then
  ln -s /usr/local/bin/update_mirrorbrain_db.sh /etc/cron.hourly/update_mirrorbrain_db.sh
fi

if [ -n $UPDATE_HASH ]
then
  ln -s /usr/local/bin/hash_mirrorbrain_db.sh /etc/cron.hourly/hash_mirrorbrain_db.sh
fi

if [ -n $HTTPD ]
then
  service cron start
  httpd-foreground -D
else
  if [ -n $UPDATE_HASH ] ||  [-n $UPDATE_DB ]
  then
    cron -d  
  fi
fi

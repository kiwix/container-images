#!/bin/sh
if [ ! -z $INIT ]
then
  init_mirrorbrain_db.sh
fi

if [ ! -z $UPDATE_DB ]
then
  echo "Install Cron to update DB"
  { \
    echo "#!/bin/sh" ; \
    echo "/usr/local/bin/update_mirrorbrain_db.sh >>/var/log/update_mb.log 2>&1" ; \
  } > /etc/cron.hourly/update_mirrorbrain_db && chmod 0500 /etc/cron.hourly/update_mirrorbrain_db
fi

if [ ! -z $UPDATE_HASH ]
then
  echo "Install Cron to update hash"
  { \
    echo "#!/bin/sh" ; \
    echo "/usr/local/bin/hash_mirrorbrain_db.sh >>/var/log/hash_mb.log 2>&1" ; \
  } > /etc/cron.hourly/hash_mirrorbrain_db && chmod 0500 /etc/cron.hourly/hash_mirrorbrain_db
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

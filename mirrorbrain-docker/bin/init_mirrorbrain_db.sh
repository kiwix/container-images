#!/bin/sh
DBNAME=mirrorbrain
DBUSER=mirrorbrain
DBHOST=db
PSQL_ARGS="-h $DBHOST -U postgres"
PSQL_MB_ARGS="-h $DBHOST  -U $DBUSER $DBNAME"
MBSQL_DIR=mirrorbrain-$MB_VERSION/sql

sleep 2

if ! psql -lqt $PSQL_ARGS | cut -d \| -f 1 | grep -qw $DBNAME; then
  createuser $PSQL_ARGS -s $DBUSER 
  createdb  $PSQL_ARGS -O $DBUSER $DBNAME 
  createlang  $PSQL_ARGS plpgsql $DBNAME
  cat $MBSQL_DIR/schema-postgresql.sql | psql $PSQL_MB_ARGS
  cat $MBSQL_DIR/initialdata-postgresql.sql | psql $PSQL_MB_ARGS
  cat $MBSQL_DIR/mirrors-postgresql.sql | psql $PSQL_MB_ARGS
fi

chown -R  www-data:www-data /var/www/download.kiwix.org

bash update_mirrorbrain_db.sh

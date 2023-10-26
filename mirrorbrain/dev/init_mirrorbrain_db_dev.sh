#!/bin/bash
DBNAME=mirrorbrain
DBUSER=mirrorbrain
DBHOST=postgresdb
PSQL_MB_ARGS="-h $DBHOST -U $DBUSER $DBNAME"
MBSQL_DIR=mirrorbrain-$MB_VERSION/sql

psql $PSQL_MB_ARGS -f <(cat $MBSQL_DIR/schema-postgresql.sql $MBSQL_DIR/initialdata-postgresql.sql $MBSQL_DIR/mirrors-postgresql.sql)

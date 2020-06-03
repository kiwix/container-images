#!/bin/bash

export PATH=/usr/local/bin:/usr/sbin:$PATH

start () {
  stop
  echo "Starting kiwix-serve..."
  kiwix-serve --daemon --port=8000 --library --threads=16 --verbose --nodatealias library.kiwix.org.xml
}

stop () {
  pid=$(pidof kiwix-serve)
  if [ ! -z $pid ];
  then
    echo "Stopping kiwix-serve..."
    kill -9 $pid
  fi
}

is_alive () {
  echo "Testing kiwix-serve..."
  curl --max-time 50 http://localhost:8000/catalog/searchdescription.xml > /dev/null 2>&1
  return $?
}

is_alive || start

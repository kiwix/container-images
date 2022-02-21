#!/bin/bash

export PATH=/usr/local/bin:/usr/sbin:$PATH

start () {
  stop
  echo "Starting kiwix-serve..."
  kiwix-serve --daemon --port=8000 --library --monitorLibrary --threads=16 --nodatealias /var/www/library.kiwix.org/library.kiwix.org.xml
  is_loaded
  if [ $? -eq 0 ] ; then
    echo "kiwix-serve ready, clearing varnish cache"
    varnish-clear
  fi
}

stop () {
  echo "Stopping kiwix-serve..."
  # kills all kiwix-serve instances if present. nothing if not
  kill -9 $(pidof kiwix-serve) > /dev/null 2>&1
}

test_url_until () {
  url=$1
  timeout=$2
  retries=$3
  duration=$4

  attempt=1
  res=1
  echo "Testing kiwix-serve..."
  while [ $attempt -le $retries ]
  do
    echo "..attempt $attempt"
    curl --max-time $timeout $url > /dev/null 2>&1
    res=$?
    if [ $res -eq 7 ];  # can't connect, either not launched or starting
    then
      ((attempt++))
      sleep $duration
    else
      echo "... can connect with $res"
      return $res
    fi
  done
  echo ".. exhausted attempts with $res"
  return $res
}

is_alive () {
  # check descriptor for 10s sleeping for 1s with a timeout of 10s
  test_url_until "http://localhost:8000/catalog/searchdescription.xml" 10 10 1
  return $?
}

is_loaded () {
  # check OPDS root for 5mn sleeping for 10s with a timeout of 30s
  test_url_until "http://localhost:8000/catalog/root.xml" 30 15 5
  return $?
}

exec 100>/var/lock/kiwix-serve || exit 1
flock -n 100 || exit 1
# passing "restart" requests a restart even if kiwix-serve alive
if [ "$1" = "restart" ];
then
  start
else
  is_alive || start
fi
flock -u 100

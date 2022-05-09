#!/bin/sh

set -e

echo "(re)building whitelist"

OFFLINE_WHITELISTED_FILES=/etc/opentracker/offline_whitelisted_files.tsv
OPENTRACKER_WHITELIST=/etc/opentracker/whitelist.txt

echo "> Retrieving published Metalink URLs from Library OPDS feed"
ONLINE_META4_URLS=$(curl --silent -L -H "Accept-Encoding: gzip" https://library.kiwix.org/catalog/root.xml | gunzip | xml2 | grep '/feed/entry/link/@href=http.*meta4' | cut -f 2 -d '=')
echo "${ONLINE_META4_URLS}" | sort > /dev/shm/online_meta4_urls.tsv

echo "> Extracting Metalink URLs from Local List"
if [ -s "${OFFLINE_WHITELISTED_FILES}" ] ; then
  cat "${OFFLINE_WHITELISTED_FILES}" | cut -f 2 | sort > /dev/shm/offline_meta4_urls.tsv
else
  touch /dev/shm/offline_meta4_urls.tsv
fi

echo "> Extracting new Metalink URLs"
comm -13 /dev/shm/offline_meta4_urls.tsv /dev/shm/online_meta4_urls.tsv > /dev/shm/new_meta4_urls.tsv
if [ ! -s /dev/shm/new_meta4_urls.tsv ] ; then echo "> none, done." ; exit 0 ; fi

echo "> Retrieving BitTorrent hashes"
CONTENT=""
rm -f /dev/shm/new_offline_whitelisted_files.tsv
echo ""
for META4_URL in $(cat /dev/shm/new_meta4_urls.tsv)
do
  BTIH_URL=$(echo $META4_URL | sed 's/meta4$/btih/')
  BTIH_DATA=$(curl --silent $BTIH_URL | sed 's/  /\t/')
  CURRENT_TIME=$(date +%s)
  retrieved=$((retrieved+1))
  echo "\e[1A\e[K> retrieved… $retrieved"
  echo "${CURRENT_TIME}\t${META4_URL}\t${BTIH_DATA}" >> /dev/shm/new_offline_whitelisted_files.tsv
done
if [ ! -s /dev/shm/new_offline_whitelisted_files.tsv ] ; then exit 0 ; fi

echo "> Merging with Local List"
cat /dev/shm/new_offline_whitelisted_files.tsv >> "${OFFLINE_WHITELISTED_FILES}"

echo "> Creating Opentracker Whitelist of hashes"
cat "${OFFLINE_WHITELISTED_FILES}" | cut -f 3 | sort -u > "${OPENTRACKER_WHITELIST}"

tpid=$(pidof opentracker) | true
if [ ! -z "$tpid" ]; then
  echo "> Requesting opentracker to reload whitelist"
  kill -s HUP $tpid
fi

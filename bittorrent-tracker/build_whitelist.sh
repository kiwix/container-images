#!/bin/sh

set -e

echo "(re)building whitelist"

OFFLINE_WHITELISTED_FILES=/etc/opentracker/offline_whitelisted_files.tsv
OPENTRACKER_WHITELIST=/etc/opentracker/whitelist.txt

SORTED_ONLINE_META4_URLS=/dev/shm/online_meta4_urls.tsv
SORTED_OFFLINE_META4_URLS=/dev/shm/offline_meta4_urls.tsv
NEW_META4_URLS=/dev/shm/new_meta4_urls.tsv
NEW_OFFLINE_WHITELISTED_FILES=/dev/shm/new_offline_whitelisted_files.tsv

echo "> Retrieving published Metalink URLs from Library OPDS feed"
ONLINE_META4_URLS=$(curl --silent -L -H "Accept-Encoding: gzip" 'https://library.kiwix.org/catalog/v2/entries?count=-1' | gunzip | xml2 | grep '/feed/entry/link/@href=http.*meta4' | cut -f 2 -d '=')
echo "${ONLINE_META4_URLS}" | sort > $SORTED_ONLINE_META4_URLS

echo "> Extracting Metalink URLs from Local List"
if [ -s "${OFFLINE_WHITELISTED_FILES}" ] ; then
  cat "${OFFLINE_WHITELISTED_FILES}" | cut -f 2 | sort > $SORTED_OFFLINE_META4_URLS
else
  touch $SORTED_OFFLINE_META4_URLS
fi

echo "> Extracting new Metalink URLs"
comm -13 $SORTED_OFFLINE_META4_URLS $SORTED_ONLINE_META4_URLS > $NEW_META4_URLS
if [ ! -s $NEW_META4_URLS ] ; then echo "> none, done." ; exit 0 ; fi

echo "> Retrieving BitTorrent hashes"
CONTENT=""
rm -f $NEW_OFFLINE_WHITELISTED_FILES
echo ""
for META4_URL in $(cat $NEW_META4_URLS)
do
  BTIH_URL=$(echo $META4_URL | sed 's/meta4$/btih/')
  set +e
  BTIH_DATA=$(curl --silent --fail $BTIH_URL)
  bith_res=$?
  set -e
  if [ "$bith_res" != "0" ]; then
    echo ".... Skipping $META4_URL (not ready)"
    continue
  fi
  BTIH_DATA=$(echo $BTIH | sed 's/  /\t/')
  echo $BTIH_DATA
  CURRENT_TIME=$(date +%s)
  retrieved=$((retrieved+1))
  echo "\e[1A\e[K> retrieved… $retrieved"
  echo "${CURRENT_TIME}\t${META4_URL}\t${BTIH_DATA}" >> $NEW_OFFLINE_WHITELISTED_FILES
done
if [ ! -s $NEW_OFFLINE_WHITELISTED_FILES ] ; then exit 0 ; fi

echo "> Merging with Local List"
cat $NEW_OFFLINE_WHITELISTED_FILES >> "${OFFLINE_WHITELISTED_FILES}"

echo "> Creating Opentracker Whitelist of hashes"
cat "${OFFLINE_WHITELISTED_FILES}" | cut -f 3 | sort -u > "${OPENTRACKER_WHITELIST}"

tpid=$(pidof opentracker) | true
if [ ! -z "$tpid" ]; then
  echo "> Requesting opentracker to reload whitelist"
  kill -s HUP $tpid
fi

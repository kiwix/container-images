#!/bin/sh

OFFLINE_WHITELISTED_FILES=/etc/opentracker/offline_whitelisted_files.tsv
OPENTRACKER_WHITELIST=/etc/opentracker/whitelist.txt

# Retrieve published Metalink URLs from library OPDS feed
ONLINE_META4_URLS=`curl --silent https://library.kiwix.org/catalog/root.xml | xml2 | grep '/feed/entry/link/@href=http.*meta4' | cut -f 2 -d '='`
echo "${ONLINE_META4_URLS}" | sort > /dev/shm/online_meta4_urls.tsv

# Extract Metalink URLs from local list
if [ ! -s "${OFFLINE_WHITELISTED_FILES}" ] ; then exit 1 ; fi
cat "${OFFLINE_WHITELISTED_FILES}" | cut -f 2 | sort > /dev/shm/offline_meta4_urls.tsv

# Extract new Metalink URLs, exit if empty
comm -13 /dev/shm/offline_meta4_urls.tsv /dev/shm/online_meta4_urls.tsv > /dev/shm/new_meta4_urls.tsv
if [ ! -s /dev/shm/new_meta4_urls.tsv ] ; then exit 0 ; fi
   
# Retrieve BitTorrent hashes
CONTENT=""
rm -f /dev/shm/new_offline_whitelisted_files.tsv
for META4_URL in `cat /dev/shm/new_meta4_urls.tsv`
do
  BTIH_URL=`echo $META4_URL | sed 's/meta4$/btih/'`
  BTIH_DATA=`curl --silent $BTIH_URL | sed 's/  /\t/'`
  CURRENT_TIME=`date +%s`
  echo "${CURRENT_TIME}\t${META4_URL}\t${BTIH_DATA}" >> /dev/shm/new_offline_whitelisted_files.tsv
done

# Concatenate with local list
cat /dev/shm/new_offline_whitelisted_files.tsv >> "${OFFLINE_WHITELISTED_FILES}"

# Create Opentracker whitelist of hashes
cat "${OFFLINE_WHITELISTED_FILES}" | cut -f 3 | sort -u > "${OPENTRACKER_WHITELIST}"

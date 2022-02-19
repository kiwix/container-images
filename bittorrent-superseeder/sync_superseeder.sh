#!/bin/sh

set -e

FEED_URL="https://library.kiwix.org/catalog/search?count=10"
CURL="curl -s"
QBT="qbt"
QBT_CREDENTIALS="--username admin --password adminadmin --url http://localhost:8080"

ONLINE_ZIM_URLS="/dev/shm/online_zim_urls.tsv"
ONLINE_ZIM_PATHS="/dev/shm/online_zim_paths.tsv"

LOCAL_ZIMS="/dev/shm/local_zims.tsv"
LOCAL_ZIM_PATHS="/dev/shm/local_zim_paths.tsv"
LOCAL_ONLY_ZIM_PATHS="/dev/shm/local_only_zim_paths.tsv"

DOWNLOAD_ZIM_PATHS="/dev/shm/download_zim_paths.tsv"
DOWNLOAD_ZIM_URLS="/dev/shm/download_zim_urls.tsv"

DOWNLOAD_PATH="/downloads"
DOWNLOAD_PATH_4_SED=$(printf '%s\n' "${DOWNLOAD_PATH}" | sed -e 's/[\/&]/\\&/g')

# Clean temporary files
for FILE in ${ONLINE_ZIM_URLS} ${ONLINE_ZIM_PATHS} ${LOCAL_ZIMS} ${LOCAL_ZIM_PATHS} ${LOCAL_ONLY_ZIM_PATHS} ${DOWNLOAD_ZIM_PATHS} ${DOWNLOAD_ZIM_URLS}
do
  rm -f ${FILE}
  touch ${FILE}
done    

# Retrieve online ZIMs
${CURL} ${FEED_URL} | xml2 | grep '^/feed/entry/link/@href=.*\.zim.*$' | sed 's/\.meta4$//' | sed 's/\/feed\/entry\/link\/@href=//' | sort > ${ONLINE_ZIM_URLS}
cat ${ONLINE_ZIM_URLS} | sed 's/^http.*:\/\/[^/]*//' | sort > ${ONLINE_ZIM_PATHS}

# Retrieve local ZIMs
${QBT} torrent list --format=json ${QBT_CREDENTIALS} | gron | sed 's/^json\[[[:digit:]]\+\]\.//' | grep -P '^(save_path|name|infohash_v1)' | sed 's/^.* = ["]*//' | sed 's/["]*;$//' | sed 'N;N;s/\n/\t/g' | awk '{ printf ("%s\t%s%s\n", $1, $3, $2) }' > ${LOCAL_ZIMS}
cat ${LOCAL_ZIMS} | cut -f2 | sed "s/^${DOWNLOAD_PATH_4_SED}//" | sort > ${LOCAL_ZIM_PATHS}

# Compute ZIMs to sync
comm -13 ${LOCAL_ZIM_PATHS} ${ONLINE_ZIM_PATHS} > ${DOWNLOAD_ZIM_PATHS}
for ZIM in `cat ${DOWNLOAD_ZIM_PATHS}`
do
  ZIM_URL=`grep -P "http[s]*://[^/]+${ZIM}$" ${ONLINE_ZIM_URLS}`

  if [ ! -z "${ZIM_URL}" ]
  then
    echo "${ZIM_URL}.torrent" >> ${DOWNLOAD_ZIM_URLS}
  fi
done
    
# Download ZIMs
for URL in `cat ${DOWNLOAD_ZIM_URLS}`
do
  echo "Downloading ${URL}..."
  ZIM_PATH=`echo ${URL} | sed 's/^http.*:\/\/[^/]*//' | sed 's/[^/]*$//'`  
  ${QBT} torrent add url ${URL} --folder="${DOWNLOAD_PATH}${ZIM_PATH}" ${QBT_CREDENTIALS}
done

# Compute ZIMs to delete
comm -23 ${LOCAL_ZIM_PATHS} ${ONLINE_ZIM_PATHS} > ${LOCAL_ONLY_ZIM_PATHS}
	   
# Delete old ZIMs
for ZIM in `cat ${LOCAL_ONLY_ZIM_PATHS}`
do
    echo "Deleting ${ZIM}..."
    ZIM_HASH=`grep -P ${ZIM} ${LOCAL_ZIMS} | cut -f1`
    ${QBT} torrent delete ${ZIM_HASH} ${PURGE_ZIM_FILES} ${QBT_CREDENTIALS}
done

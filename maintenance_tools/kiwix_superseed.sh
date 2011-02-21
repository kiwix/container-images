#!/bin/bash

TORRENT_DIR=./
WEB_DIR=http://download.kiwix.org/
SYNC_DIRS="archive portable zim/0.9"

cd $TORRENT_DIR

for DIR in $SYNC_DIRS
do
    for FILE in `rsync -az download.kiwix.org::download.kiwix.org/$DIR/ | sed -e 's/^.* //g' | grep '\....'`
    do
	TORRENT_FILE=$WEB_DIR$DIR/$FILE.torrent
	LOCAL_FILE=`echo $FILE.torrent | sed -e 's/.*\///m'`
	if [ -e "$LOCAL_FILE" ]
	then
	    echo "Skipping $TORRENT_FILE..."
	else
	    echo "Downloading $TORRENT_FILE..."
	    wget "$TORRENT_FILE"
	fi
    done
done
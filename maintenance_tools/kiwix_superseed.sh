#!/bin/bash

TORRENT_DIR=/home/kelson/rtorrent/watch/
INBOX_DIR=/home/kelson/rtorrent/inbox/
SOURCE_DIR=/var/www/download.kiwix.org/
WEB_DIR=http://download.kiwix.org/
SYNC_DIRS="archive portable zim/0.9"

if [ ! "$1" == "--linkFiles" ]
then
    INBOX_DIR=
fi

for DIR in $SYNC_DIRS
do
    for FILE in `rsync -az download.kiwix.org::download.kiwix.org/$DIR/ | sed -e 's/^.* //g' | grep '\....'`
    do

	cd $TORRENT_DIR
	TORRENT_FILE=$WEB_DIR$DIR/$FILE.torrent
	LOCAL_FILE=`echo $FILE.torrent | sed -e 's/.*\///m'`
	if [ -e "$LOCAL_FILE" ]
	then
	    echo "Skipping $TORRENT_FILE..."
	else
	    echo "Downloading $TORRENT_FILE..."
	    wget "$TORRENT_FILE"
	fi

	if [ ! $INBOX_DIR == "" ]
	then
	    SOURCE_LINK=$SOURCE_DIR$DIR/$FILE
	    LOCAL_FILE=`echo $FILE | sed -e 's/.*\///m'`
	    cd $INBOX_DIR
	    if [ -e $LOCAL_FILE ]
	    then
		echo "Skipping $FILE linking..."
	    else
		echo "Linking $SOURCE_LINK..."
		ln "$SOURCE_LINK"  
	    fi
	fi
    done
done
#!/bin/bash

SOURCE_DIR=$1

if [ ! -e "$SOURCE_DIR" ]
then
    echo "You have to give the web download directory root like /var/www/download.kiwix.org/"
    exit 1
fi 

TORRENT_DIR=/home/kelson/rtorrent/watch/
INBOX_DIR=/home/kelson/rtorrent/inbox/
WEB_DIR=http://download.kiwix.org/
SYNC_DIRS="archive/kiwix archive/moulinwiki portable zim/0.9 zim/other"

for DIR in $SYNC_DIRS
do
    for FILE in `ls -1 -F $SOURCE_DIR/$DIR/ | grep -v "ignore" | grep -v "~" | sed -e 's/^.* //g' | grep '\....'`
    do
	if [ ! $INBOX_DIR == "" ]
	then
	    SOURCE_LINK=$SOURCE_DIR/$DIR/$FILE
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

	cd $TORRENT_DIR
	TORRENT_FILE=$WEB_DIR/$DIR/$FILE.torrent
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
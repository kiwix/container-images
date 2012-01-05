#!/bin/bash

RTORRENT_DIR=/home/kelson/rtorrent/
PORTABLE_DIR=/var/www/download.kiwix.org/portable/
CONTENT=$1

# remove portable version
cd $PORTABLE_DIR
if [ "$CONTENT" == "" ]
then
    for CONTENT in `find $PORTABLE_DIR -name "*zip"| cut -d "+" -f 2 | sort -u | sed -e "s/.zip//g"`
    do
	for FILE2DELETE in `cd $PORTABLE_DIR ; ls -alrt *$CONTENT* | head -n -1 | awk '{print $8}'`
	do
	    echo "Removing $FILE2DELETE files..."
	    rm $PORTABLE_DIR$FILE2DELETE
	    rm $RTORRENT_DIR/watch/$FILE2DELETE.torrent
	    rm $RTORRENT_DIR/inbox/$FILE2DELETE
	done
    done
else
    FILE2DELETE=`cd $PORTABLE_DIR ; ls -alrt *$CONTENT* | cut -d " " -f 8`
    echo "Removing $FILE2DELETE files..."
    rm $PORTABLE_DIR$FILE2DELETE
    rm $RTORRENT_DIR/watch/$FILE2DELETE.torrent
    rm $RTORRENT_DIR/inbox/$FILE2DELETE
fi
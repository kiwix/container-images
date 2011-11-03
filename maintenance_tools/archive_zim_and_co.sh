#!/bin/bash

ZIM_FILENAME=$1
ZIM_FILENAME_CORPUS=`echo $ZIM_FILENAME | sed s/\.zim//g`
RTORRENT_DIR=/home/kelson/rtorrent/
ZIM_DIR=/var/www/download.kiwix.org/zim/0.9/
ARCHIVE_DIR=/var/www/download.kiwix.org/archive/zim/0.9/
PORTABLE_DIR=/var/www/download.kiwix.org/portable/

# usage
if [ "$ZIM_FILENAME" == "" ]
then
    echo "Usage: archive_zim_and_co.sh testfile.zim"
    exit
fi

# mv ZIM file to archive
OLD_ZIM_PATH=$ZIM_DIR$ZIM_FILENAME
NEW_ZIM_PATH=$ARCHIVE_DIR$ZIM_FILENAME
if [ -f $OLD_ZIM_PATH ]
then
    echo "Moving $ZIM_FILENAME to $ARCHIVE_DIR..."
    mv $OLD_ZIM_PATH $NEW_ZIM_PATH
else
    if [ -f $NEW_ZIM_PATH ]
    then
	echo "$ZIM_FILENAME already moved to $ARCHIVE_DIR"
    else
	echo "$ZIM_FILENAME seems not to exist at all neither in $ZIM_DIR nor in $ARCHIVE_DIR."
	exit
    fi
fi

# remove portable version
cd $PORTABLE_DIR
for FILENAME in `find . -name "*$ZIM_FILENAME_CORPUS.zip" | sed -e "s/^\.\///g"`
do
    echo "Removing $PORTABLE_DIR$FILENAME..."
    rm -f $FILENAME
done

# remove torrent files
cd $RTORRENT_DIR
for FILENAME in `find . -name "*$ZIM_FILENAME_CORPUS.zi*" | sed -e "s/^\.\///g"`
do
    echo "Removing $RTORRENT_DIR$FILENAME..."
    rm -f $FILENAME
done

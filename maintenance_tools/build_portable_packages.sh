#!/bin/bash

TARGET_DIR=/var/www/download.kiwix.org/portable/
SCRIPT=/var/www/kiwix/tools/scripts/buildDistributionFile.pl
SYNC_DIRS="zim/0.9"
KIWIX_VERSION=`ls -la /var/www/download.kiwix.org/bin/unstable | cut -d " " -f10`

for DIR in $SYNC_DIRS
do
    for FILE in `rsync -az download.kiwix.org::download.kiwix.org/$DIR/ | sed -e 's/^.* //g' | grep '\....'`
    do
	FILENAME=$KIWIX_VERSION+`echo $FILE| sed -e 's/zim/zip/g'`
	
	if [ ! -f "$TARGET_DIR"/"$FILENAME" ]
	then
	    echo "Building $FILENAME..."
	    $SCRIPT --filePath="/tmp/$FILENAME" --zimPath=/var/www/download.kiwix.org/zim/0.9/$FILE --type=portable
	    mv /tmp/$FILENAME $TARGET_DIR/
	else
	    echo "Skipping $FILENAME..."
	fi
    done
done
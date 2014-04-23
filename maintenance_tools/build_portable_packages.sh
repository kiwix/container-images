#!/bin/bash
SOURCE=/var/www/download.kiwix.org/zim/
TARGET=/var/www/download.kiwix.org/portable/
TMP=/tmp/
SCRIPT=/var/www/kiwix/tools/tools/scripts/buildDistributionFile.pl
VERSION=`ls -la /var/www/download.kiwix.org/bin/unstable | cut -d " " -f12 | sed -e 's/_/-/g' | sed -e 's/\///g'` 
EXCLUDE="0.9"

SOURCE_ESC=`echo "$SOURCE" | sed 's/\//\\\\\//g'`


for DIR in `find "$SOURCE" -type d | sed "s/$SOURCE_ESC//" | grep -v "$EXCLUDE"`
do
    echo "Searching for ZIM files in '$SOURCE$DIR'"
    DIR_ESC=`echo "$DIR/" | sed 's/\//\\\\\//g'`

    if [ ! -d "$TARGET$DIR" ]
    then
	echo "Creating directory '$TARGET$DIR'"
	mkdir -p "$TARGET$DIR"
    fi

    for ZIMFILE in `find "$SOURCE$DIR" -maxdepth 1 -name '*.zim' -type f | sed "s/$SOURCE_ESC$DIR_ESC//"`
    do
	ZIPFILE="kiwix-"$VERSION+`echo $ZIMFILE | sed -e 's/zim/zip/g'`
	if [ ! -f "$TARGET$DIR/$ZIPFILE" ]
	then
	    echo "Building $ZIPFILE..."
	    cd `dirname "$SCRIPT"`
	    $SCRIPT --filePath="$TMP$ZIPFILE" --zimPath="$SOURCE$DIR/$ZIMFILE" --type=portable
    
	    echo "Move $TMP$ZIPFILE to $TARGET$DIR"
	    mv "$TMP$ZIPFILE" "$TARGET$DIR"
	else
	    echo "Skipping $ZIPFILE..."
	fi
    done
done

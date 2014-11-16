#!/bin/bash
SOURCE=/var/www/zimfarm.kiwix.org/upload/zim2index/
ZIMTARGET=/var/www/zimfarm.kiwix.org/upload/zim/
ZIPTARGET=/var/www/zimfarm.kiwix.org/upload/portable/
TMP=/media/data/prod/kiwix-maintenance/maintenance_tools/tmp/
SCRIPT=/media/data/prod/kiwix-tools/tools/scripts/buildDistributionFile.pl
VERSION=`readlink /var/www/download.kiwix.org/bin/unstable | sed -e 's/_/-/g' | sed -e 's/\///g'` 
EXCLUDE="0.9"

SOURCE_ESC=`echo "$SOURCE" | sed 's/\//\\\\\//g'`


for DIR in `find "$SOURCE" -type d | sed "s/$SOURCE_ESC//" | grep -v "$EXCLUDE"`
do
    echo "Searching for ZIM files in '$SOURCE$DIR'"
    DIR_ESC=`echo "$DIR/" | sed 's/\//\\\\\//g'`

    if [ ! -d "$ZIPTARGET$DIR" ]
    then
	echo "Creating ZIP directory '$ZIPTARGET$DIR'"
	mkdir -p "$ZIPTARGET$DIR"
    fi

    if [ ! -d "$ZIMTARGET$DIR" ]
    then
	echo "Creating ZIM directory '$ZIMTARGET$DIR'"
	mkdir -p "$ZIMTARGET$DIR"
    fi

    for ZIMFILE in `find "$SOURCE$DIR" -maxdepth 1 -name '*.zim' -type f | sed "s/$SOURCE_ESC$DIR_ESC//"`
    do
	ZIPFILE="kiwix-"$VERSION+`echo $ZIMFILE | sed -e 's/zim/zip/g'`
	if [ ! -f "$ZIPTARGET$DIR/$ZIPFILE" ]
	then
	    echo "Building $ZIPFILE..."
	    cd `dirname "$SCRIPT"`
	    $SCRIPT --filePath="$TMP$ZIPFILE" --zimPath="$SOURCE$DIR/$ZIMFILE" --tmpDirectory="$TMP" --type=portable --downloadMirror=download_dev_mirror
    
	    echo "Move $TMP$ZIPFILE to $ZIPTARGET$DIR"
	    mv "$TMP$ZIPFILE" "$ZIPTARGET$DIR"

	    echo "Move $SOURCE$DIR/$ZIMFILE to $ZIMTARGET$DIR"
	    mv "$SOURCE$DIR/$ZIMFILE" "$ZIMTARGET$DIR"
	else
	    echo "Skipping $ZIPFILE..."
	fi
    done
done

#!/bin/bash

# OLD for zimfarm.kiwix.org
#SOURCE=/var/www/zimfarm.kiwix.org/upload/zim2index/
#ZIMTARGET=/var/www/zimfarm.kiwix.org/upload/zim/
#ZIPTARGET=/var/www/zimfarm.kiwix.org/upload/portable/
#TMP=/media/data/prod/kiwix-maintenance/maintenance_tools/tmp/
#SCRIPT=/media/data/prod/kiwix-tools/tools/scripts/buildDistributionFile.pl
#VERSION=`readlink /var/www/download.kiwix.org/bin/unstable | sed -e 's/_/-/g' | sed -e 's/\///g'` 

# New for mwoffliner VMs
SOURCE=/srv/upload/zim2index/
ZIMTARGET=/srv/upload/zim/
ZIPTARGET=/srv/upload/portable/
TMP=/data/scratch/mwoffliner/tmp/
SCRIPT=/srv/kiwix-tools/tools/scripts/buildDistributionFile.pl
VERSION=`readlink /srv/download.kiwix.org/bin/unstable | sed -e 's/_/-/g' | sed -e 's/\///g'`

EXCLUDE="(0.9|indexdb.tmp)"
SOURCE_ESC=`echo "$SOURCE" | sed 's/\//\\\\\//g'`

for DIR in `find "$SOURCE" -type d | sed "s/$SOURCE_ESC//" | egrep -v "$EXCLUDE"`
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
	ACCESSED=`lsof "$SOURCE$DIR/$ZIMFILE"`
	if [[ ! -f "$ZIPTARGET$DIR/$ZIPFILE" && ! "$ACCESSED" ]]
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

#!/bin/bash

ZIM_DIRECTORY=/var/www/download.kiwix.org/zim/
IDX_DIRECTORY=/var/www/library.kiwix.org/
LIBRARY_PATH=/var/www/library.kiwix.org/library.xml
ALIAS_PATH=/var/www/kiwix/maintenance/maintenance_tools/contents.alias
ALIAS_DIRECTORY=$IDX_DIRECTORY
PORT=4200

# Delete library
rm -f $LIBRARY_PATH

# Remove Alias symlinks
for ALIAS in `find $ALIAS_DIRECTORY -name "*.zim"`
do
    unlink $ALIAS
done

# Go trough all ZIM files, build idx file and library.xml
for ZIM in `find $ZIM_DIRECTORY -name "*.zim" | grep -v "0.8/"`
do
    echo $ZIM
    BASE=`echo $ZIM | sed -e "s/.*\///g"`
    IDX=$IDX_DIRECTORY/$BASE.idx
    echo "Checking search index for $BASE"
    if [ ! -e $IDX ]
    then
	echo "Building idx for $ZIM..."
	kiwix-index --verbose $ZIM $IDX
	kiwix-compact $IDX
    fi

    # Check for alias
    ALIAS=`cat $ALIAS_PATH | grep $BASE | cut -d" " -f1`
    echo "$BASE $ALIAS"
    if [ ! $ALIAS == "" ]
    then
	echo "Creating alias link for $BASE ($ALIAS)"
	ZIM_ALIAS_PATH=$ALIAS_DIRECTORY/$ALIAS
	ln -s $ZIM $ZIM_ALIAS_PATH
	ZIM=$ZIM_ALIAS_PATH
    fi

    # Add to library
    echo "Adding $BASE to library.xml..."
    kiwix-manage $LIBRARY_PATH add $ZIM --indexPath=$IDX 
done

# kill kiwix-serve instances
echo "Killing old kiwix-serve instance(s)"
if [ ! "`pidof kiwix-serve`" == "" ]
then
    kill -9 `pidof kiwix-serve`
fi

# Start kiwix-serve
echo "Running kiwix-serve..."
while true
do 
    kiwix-serve --verbose --library --port=$PORT $LIBRARY_PATH
    sleep 10
done


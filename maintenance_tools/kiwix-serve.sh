#!/bin/bash

ZIM_DIRECTORY=/var/www/download.kiwix.org/zim/
IDX_DIRECTORY=/var/www/library.kiwix.org/
LIBRARY_PATH=/var/www/library.kiwix.org/library.xml
PORT=4242

# Delete library
rm -f $LIBRARY_PATH

# Go trough all ZIM files, build idx file and library.xml
for ZIM in `find /var/www/download.kiwix.org/zim/ -name "*.zim" | grep -v "0.8"`
do
    echo $ZIM
    BASE=`echo $ZIM | sed -e "s/.*\///g"`
    IDX=$IDX_DIRECTORY/$BASE.idx
    echo "Checkin search index for $BASE"
    if [ ! -e $IDX ]
    then
	echo "Building idx for $ZIM..."
	kiwix-index --backend=xapian $ZIM $IDX
	kiwix-compact $IDX
    fi

    # Add to library
    kiwix-manage $LIBRARY_PATH add $ZIM --indexPath=$IDX --indexBackend=xapian
done

# kill kiwix-serve instances
if [ ! "`pidof kiwix-serve`" == "" ]
then
    kill -9 `pidof kiwix-serve`
fi

# Start kiwix-serve
kiwix-serve --library --port=$PORT $LIBRARY_PATH
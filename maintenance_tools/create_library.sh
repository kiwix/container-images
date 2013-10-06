#!/bin/sh

ZIMDIR=/var/www/download.kiwix.org/zim/
LIBRARYFILE=`pwd`/library.xml

# Delete file, otherwise this will be an overwrite and old values
# will be taken in account.
rm $LIBRARYFILE

cd $ZIMDIR

for DIR in *
do
    if [ -d $ZIMDIR/$DIR ]
    then
      cd $ZIMDIR/$DIR
      echo "Changing directory to $ZIMDIR/$DIR ..."
      for FILE in `find . -name "*zim"`
      do
	FILE=`echo "$FILE" | sed -e "s/\.\///"`
	FOUND=1

	if [ -f .ignore ]
	then
	    grep $FILE .ignore > /dev/null
	    FOUND=$?
	fi

	if [ "$FOUND" -eq "1" ]
	then
	    echo "Inserting $FILE ..."
	    kiwix-manage $LIBRARYFILE add $FILE --zimPathToSave="" --url=http://download.kiwix.org/zim/$DIR/$FILE.meta4
	fi
      done
    fi
done
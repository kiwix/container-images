#!/bin/sh

ZIMDIR=/var/www/download.kiwix.org/zim/0.9/
LIBRARYFILE=`pwd`/library.xml

# Delete file, otherwise this will be an overwrite and old values
# will be taken in account.
rm $LIBRARYFILE

cd $ZIMDIR

for FILE in `find . -name "*zim"`
do
  FILE=`echo "$FILE" | sed -e "s/\.\///"`
  grep $FILE .ignore > /dev/null
  if [ "$?" -eq "1" ]
  then
      echo "Inserting $FILE ..."
      kiwix-manage $LIBRARYFILE add $FILE --zimPathToSave="" --url=http://download.kiwix.org/zim/0.9/$FILE.metalink
  fi
done
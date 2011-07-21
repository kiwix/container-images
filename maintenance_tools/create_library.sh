#!/bin/sh

ZIMDIR=/var/www/download.kiwix.org/zim/0.9/
LIBRARYFILE=`pwd`/library.xml

cd $ZIMDIR

for FILE in `find . -name "*zim"`
do
  FILE=`echo "$FILE" | sed -e "s/\.\///"`
  grep $FILE .ignore > /dev/null
  if [ "$?" -eq "1" ]
  then
      kiwix-manage $LIBRARYFILE add $FILE
  fi
done
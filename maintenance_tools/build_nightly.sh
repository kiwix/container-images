#!/bin/sh

DEST=$1
TMP=/tmp
DIR=$TMP/kiwix

# clean
rm -rf $DIR

# get the code from the svn
svn co https://kiwix.svn.sourceforge.net/svnroot/kiwix/moulinkiwix $DIR

# change dir
cd $DIR

# configure
./autogen.sh
./configure

# make the dist file
make dist-bzip2

# move to destination dir
mv ./kiwix-svn.tar.bz2 $DEST/kiwix-svn-`date "+%Y-%m-%d"`.tar.bz2
#!/bin/sh

export MY_PATH=`pwd`


rm -rf zlib-1.2.3.tar.gz zlib
wget http://www.zlib.net/zlib-1.2.3.tar.gz || exit
tar -xvzf zlib-1.2.3.tar.gz
mv zlib-1.2.3 zlib

cd zlib
./autogen.sh
./configure || exit
make clean || exit
make all || exit



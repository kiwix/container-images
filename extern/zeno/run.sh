#!/bin/sh

export MY_PATH=`pwd`

export CPPFLAGS="-I$MY_PATH/cxxtools/include/ -I$MY_PATH/tntnet/framework/common/ -I$MY_PATH/tntdb/include/"
export LDFLAGS="-L$MY_PATH/cxxtools/src/unit/.libs/ -L$MY_PATH/cxxtools/src/.libs/ -L$MY_PATH/tntnet/framework/common/.libs/ -L$MY_PATH/tntdb/src/.libs/"
export LD_LIBRARY_PATH="$MY_PATH/cxxtools/src/unit/.libs/:$MY_PATH/cxxtools/src/.libs/:$MY_PATH/tntnet/framework/common/.libs/:$MY_PATH/tntdb/src/.libs/:$MY_PATH/tntdb/src/postgresql/.libs/:$MY_PATH/tntdb/src/sqlite/.libs/"
export PATH="$PATH:$MY_PATH/cxxtools/:$MY_PATH/tntnet/sdk/tools/ecppc/"

rm -r tntnet-1.6.3.tar.gz tntnet
wget --continue http://www.tntnet.org/download/tntnet-1.6.3.tar.gz || exit
tar -xvzf tntnet-1.6.3.tar.gz
mv tntnet-1.6.3 tntnet

rm -rf cxxtools-1.4.8.tar.gz cxxtools
wget --continue http://www.tntnet.org/download/cxxtools-1.4.8.tar.gz || exit
tar -xvzf cxxtools-1.4.8.tar.gz
mv  cxxtools-1.4.8 cxxtools

rm -rf tntdb-1.0.1.tar.gz tntdb
wget --continue http://www.tntnet.org/download/tntdb-1.0.1.tar.gz || exit
tar -xvzf tntdb-1.0.1.tar.gz
mv tntdb-1.0.1 tntdb

svn co https://tntzenoreader.svn.sourceforge.net/svnroot/tntzenoreader/trunk tntzenoreader || exit

for PROJ in `echo "cxxtools tntnet tntdb tntzenoreader"` ; do
  echo "== $PROJ ==============================================";
  cd $PROJ
  ./autogen.sh

  if [ "$PROJ" = "tntdb" ]; then
      echo "./configure --without-postgresql --without-mysql --without-oracle --without-doxygen"
    ./configure --without-postgresql --without-mysql --without-oracle --without-doxygen || exit
  else
    ./configure || exit
  fi

  make || exit
  cd ..
done

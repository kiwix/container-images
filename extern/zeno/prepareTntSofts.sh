#!/bin/sh

MY_PATH=`pwd`

export CPPFLAGS="-I$MY_PATH/cxxtools/include/ -I$MY_PATH/tntnet/framework/common/ -I$MY_PATH/tntdb/include/"
export LDFLAGS="-L$MY_PATH/cxxtools/src/unit/.libs/ -L$MY_PATH/cxxtools/src/.libs/ -L$MY_PATH/tntnet/framework/common/.libs/ -L$MY_PATH/tntdb/src/.libs/"
export LD_LIBRARY_PATH="$MY_PATH/cxxtools/src/unit/.libs/:$MY_PATH/cxxtools/src/.libs/:$MY_PATH/tntnet/framework/common/.libs/:$MY_PATH/tntdb/src/.libs/:$MY_PATH/tntdb/src/postgresql/.libs/:$MY_PATH/tntdb/src/sqlite/.libs/"
export PATH="$PATH:$MY_PATH/cxxtools/:$MY_PATH/tntnet/sdk/tools/ecppc/"

source setLdPath.sh

for PROJ in `echo "cxxtools tntnet tntdb tntzenoreader"` ; do
  if [ "$PROJ" != "tntzenoreader" ]; then
    svn co https://$PROJ.svn.sourceforge.net/svnroot/$PROJ/trunk/$PROJ $PROJ 
  else
    svn co https://$PROJ.svn.sourceforge.net/svnroot/$PROJ/trunk/ $PROJ 
  fi

  cd $PROJ
  ./autogen.sh
  ./configure
  make clean
  make
  cd ..
done
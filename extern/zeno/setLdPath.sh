#!/bin/sh

MY_PATH=`pwd`

export LD_LIBRARY_PATH="$MY_PATH/cxxtools/src/unit/.libs/:$MY_PATH/cxxtools/src/.libs/:$MY_PATH/tntnet/framework/common/.libs/:$MY_PATH/tntdb/src/.libs/:$MY_PATH/tntdb/src/postgresql/.libs/:$MY_PATH/tntdb/src/sqlite/.libs/"
export PATH="$PATH:$MY_PATH/cxxtools/:$MY_PATH/tntnet/sdk/tools/ecppc/"

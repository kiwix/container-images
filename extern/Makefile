all: download compile

download:
	wget -c http://www.gzip.org/zlib/zlib-1.2.3.tar.gz
	if [ ! -d zlib-1.2.3 ]; then tar -xvzf zlib-1.2.3.tar.gz ; fi
	wget -c http://www.bzip.org/1.0.5/bzip2-1.0.5.tar.gz
	if [ ! -d bzip2-1.0.5 ]; then tar -xvzf bzip2-1.0.5.tar.gz ; fi
	wget -c	http://oligarchy.co.uk/xapian/1.0.10/xapian-core-1.0.10.tar.gz
	if [ ! -d xapian-core-1.0.10 ]; then tar -xvzf xapian-core-1.0.10.tar.gz ; fi
	if [ -d cxxtools ]; then cd cxxtools ; svn update ; cd .. ; else \
	svn co https://cxxtools.svn.sourceforge.net/svnroot/cxxtools/trunk/cxxtools cxxtools ; fi
	if [ -d tntzenoreader ]; then cd tntzenoreader ; svn update ; cd .. ; else \
	svn co https://tntzenoreader.svn.sourceforge.net/svnroot/tntzenoreader/trunk tntzenoreader ; fi

compile:
	cd bzip2-1.0.5 ; sed -i "s/CFLAGS=/CFLAGS=-fPIC /" Makefile ; make ; cd ..
	cd zlib-1.2.3 ; export CFLAGS=" -fPIC " ; ./configure ; make ; cd ..
	cd xapian-core-1.0.10 ; export CXXFLAGS=" -fPIC " ; ./configure ; make ; cd ..
	cd cxxtools ; ./autogen.sh ; export CXXFLAGS=" -fPIC " ; ./configure ; make ; \
	cd src ; ar cr libcxxtools.a *.o ; ranlib libcxxtools.a ; mv libcxxtools.a .libs ; cd ../..
	export MY_PATH=`pwd` ;  export CXXFLAGS=" -fPIC " ; export CPPFLAGS="-I$$MY_PATH/cxxtools/include/" ; export LDFLAGS="-L$$MY_PATH/cxxtools/src/unit/.libs/ -L$$MY_PATH/cxxtools/src/.libs/" ; echo $$LDFLAGS ; echo $$CPPFLAGS ; cd tntzenoreader ; ./autogen.sh ; ./configure --with-reader=no --with-writer=no ; make ; cd ..

clean:
	rm -rf zlib* bzip* cxxtools tntzenoreader xapian* *~

#!/bin/bash

ssh -p 2222 root@localhost <<'EOF'
# update the distribution
yum -y update

# install packages
yum -y install xulrunner xulrunner-devel subversion xapian-core xapian-core-devel wget gcc-c++ libtool automake autoconf libmicrohttpd libmicrohttpd-devel rpm-build bzip2-devel

# libunac
wget http://download.kiwix.org/dev/unac-1.7.0-1.i386.rpm
rpm --install --force unac-1.7.0-1.i386.rpm

# build the dist file
cd /tmp
rm -rf moulinkiwix
svn co https://kiwix.svn.sourceforge.net/svnroot/kiwix/moulinkiwix
cd moulinkiwix
./autogen.sh
./configure --with-xpidl=/usr/lib/xulrunner-`pkg-config --modversion libxul`/ --with-gecko-idl=/usr/lib/xulrunner-sdk-`pkg-config --modversion libxul`/sdk/idl

# build the RPM
make rpm

EOF

# Get the RPM file
scp -P 2222 root@localhost:/tmp/moulinkiwix/kiwix*.rpm .
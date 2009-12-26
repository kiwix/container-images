#!/bin/bash

PORT=2222
USER=root
PASS=kelson
ISO=""
NAME=""
IMG=""
PWD=`pwd`

function startVM {
    qemu -hda "$IMG" -redir tcp:2222::22 -nographic &
    WAIT=1
    while [ "$WAIT" = "1" ]
    do 
	nc -z localhost 2222 ;
	WAIT=$?
	echo "Virtual machine starting..."
	sleep 1
    done
}

function stopVM {
    kill -0 `pidof qemu`
}

function buildRPM {
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
    scp -P 2222 root@localhost:/tmp/moulinkiwix/kiwix*.rpm $PWD/

    # stop
    shutdown now
}

function buildDeb {
    echo "todo"
}

function usage {
    echo "./build_package?with_wm.sh ACTION ARGS"
    echo "       --install ISO NAME"
    echo "       --list"
    echo "       --buildRpm NAME"
    echo "       --buildDeb NAME"
}

function checkNameAndImg {
    if [ ! -d "$NAME" ]
    then
	echo "~/qemu/$NAME directory does not exist."
	exit 1
    fi

    if [ ! -f "$NAME"/"$IMG" ]
    then
	echo "~/qemu/$NAME/$IMG does not exist."
	exit 1
    fi
}

# Parse arguments
if [ "$1" = "--install" ]
then
    ISO="$2"
    NAME="$3"

    if [ "$ISO" = "" ]||[ "$NAME" = "" ] 
    then
	usage
    else
	IMG="$NAME.img"
	cd ~/qemu/
	if [ ! -d "$NAME" ]
	then
	    mkdir "$NAME"
	fi
	cd "$NAME"
	
	if [ ! -f "$IMG" ]
	then
	    qemu-img create "$IMG" 5G
	fi
	qemu -hda "$IMG" -cdrom "$ISO" -m 1024 -boot d
    fi
elif [ "$1" = "--list" ]
then
    for FILE in `find ~/qemu -name "*img" | sed "s/\.img//"` ; do basename $FILE ; done
elif [ "$1" = "--buildRpm" ]
then
    NAME="$2"
    IMG="$NAME.img"
    cd ~/qemu/

    checkNameAndImg

    cd "$NAME"
    startVM
    buildRPM
    stopVM
else
    usage
fi
#!/bin/bash

# Variables & functions
echo "Setting up variables..."
MB=/usr/local/bin/mb
REPO="/var/www/download.kiwix.org/"
ESCREPO=`echo "$REPO" | sed -e 's/[\\/&]/\\\\&/g'`
ALLDIRS=`find "$REPO" -maxdepth 1 -type d | sed "s/$ESCREPO//"`
WMDIRS=`find "$REPO" -type d -name "*wikipedia*" -o -type d -name "*wiktionary*" -o -type d -name "*wikisource*" -o -type d -name "*wikibooks*" -o -type d -name "*wikivoyage*" -o -type d -name "*wikiquote*" -o -type d -name "*wikinews*" -o -type d -name "*wikiversity*" | sed "s/$ESCREPO//" | grep -v -e "^archive/"`
ZIMDIRS="zim"

function scanMirror() {
    MIRROR=$1
    DIRS=${!2}

    for DIR in $DIRS
    do
        echo "Scanning mirror '$MIRROR' at $DIR"
        $MB scan -d "$DIR" $MIRROR
    done
}

# Clean up the db
echo "Cleaning up the mirrorbrain database..."
$MB db vacuum

# Scan the driftle.ss mirrors
scanMirror ny.mirror.driftle.ss ALLDIRS
scanMirror wi.mirror.driftle.ss ALLDIRS

# Scan the ftp.acc.umu.se mirror (two offloaders)
scanMirror saimei.ftp.acc.umu.se ALLDIRS
scanMirror laotzu.ftp.acc.umu.se ALLDIRS

# Scan the dotsrc.org mirror
scanMirror mirrors.dotsrc.org ALLDIRS

# Scan the triplebit.org mirror
scanMirror mirror.triplebit.org ALLDIRS

# scan the Kiwix mirrors
scanMirror mirror.download.kiwix.org ALLDIRS

# Scan the ISOC Israel mirror
scanMirror mirror.isoc.org.il ZIMDIRS

# Scan the Your.org mirror
scanMirror ftpmirror.your.org WMDIRS

# Scan the nluug.nl mirror
scanMirror ftp.nluug.nl ALLDIRS

# Scan the Mirrorservice.org mirror
scanMirror www.mirrorservice.org ALLDIRS

# Scan the fau.de mirror
scanMirror ftp.fau.de ALLDIRS

# Scan the hacktegic mirror
scanMirror md.mirrors.hacktegic.com ALLDIRS

# Scan MB Group mirrors
scanMirror mirror-sites-fr.mblibrary.info ALLDIRS
scanMirror mirror-sites-ca.mblibrary.info ALLDIRS
scanMirror mirror-sites-in.mblibrary.info ALLDIRS

# Scan the Wikimedia mirror
scanMirror dumps.wikimedia.org WMDIRS

# Generate HTML mirrors list
mb mirrorlist -f xhtml --html-header /etc/mirrorlist_header.txt | grep -v @ > /var/www/download.kiwix.org/mirrors.html


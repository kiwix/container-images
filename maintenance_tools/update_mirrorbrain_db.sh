#!/bin/bash

# Variables & functions
echo "Setting up variables..."
MB=/usr/local/bin/mb
REPO="/var/www/download.kiwix.org/"
ESCREPO=`echo "$REPO" | sed -e 's/[\\/&]/\\\\&/g'`
ALLDIRS=`find "$REPO" -type d | sed "s/$ESCREPO//"`
WMDIRS=`find "$REPO" -type d -name "*wikinews*" -o -type d -name "*wikipedia*" -o -type d -name "*wiktionary*" -o -type d -name "*wikisource*" -o -type d -name "*wikibooks*" -o -type d -name "*wikivoyage*" -o -type d -name "*wikiquote*" -o -type d -name "*wikispecies*" -o -type d -name "*wikinews*" -o -type d -name "*wikiversity*" -o -type d -name "*0.9*" | sed "s/$ESCREPO//"`

function scanMirror() {
    MIRROR=$1
    DIRS=${!2}
    
    for DIR in $DIRS
    do
	echo "Scanning mirror '$MIRROR' at $DIR"
	$MB scan -d "$DIR" $MIRROR > /dev/null 2>&1
    done
}

# Clean up the db
echo "Cleaning up the mirrorbrain database..."
$MB db vacuum > /dev/null 2>&1

# Build hash for new files in the master directory
echo "Building hash for new files..."
$MB makehashes $REPO -t /usr/share/mirrorbrain > /dev/null 2>&1

# Check if mirrors are online
echo "Checking if mirrors are online..."
mirrorprobe > /dev/null 2>&1

# scan the Kiwix mirrors
scanMirror kiwix ALLDIRS
scanMirror mirror2 ALLDIRS
scanMirror mirror3 ALLDIRS

# Scan Tunisian mirror
scanMirror mirror.tn ALLDIRS

# Scan the Wikimedia mirror
scanMirror wikimedia WMDIRS

# Scan the ISOC Israel mirror
scanMirror isoc.il WMDIRS

# Scan the Your.org mirror
scanMirror your.org WMDIRS

# Scan the Mirrorservice.org mirror
scanMirror mirrorservice.org WMDIRS

# Scan the fau.de mirror
scanMirror fau.de ALLDIRS

# Scan the NetCologne mirror
scanMirror netcologne.de ALLDIRS


#!/bin/bash

# Variables & functions
echo "Setting up variables..."
MB=/usr/local/bin/mb
REPO="/var/www/download.kiwix.org/"
ESCREPO=`echo "$REPO" | sed -e 's/[\\/&]/\\\\&/g'`
ALLDIRS=`find "$REPO" -type d | sed "s/$ESCREPO//"`
WMDIRS=`find "$REPO" -type d -name "*wikinews*" -o -type d -name "*wikipedia*" -o -type d -name "*wiktionary*" -o -type d -name "*wikisource*" -o -type d -name "*wikibooks*" -o -type d -name "*wikivoyage*" -o -type d -name "*wikiquote*" -o -type d -name "*wikispecies*" -o -type d -name "*wikinews*" -o -type d -name "*wikiversity*" -o -type d -name "*0.9*" | sed "s/$ESCREPO//"`
ZIMDIRS=`find "$REPO" -type d | grep "${REPO}zim"| sed "s/$ESCREPO//"`

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

# Build hash for new files in the master directory
#echo "Building hash for new files..."
#$MB makehashes $REPO -t /usr/share/mirrorbrain 

# Check if mirrors are online
echo "Checking if mirrors are online..."
mirrorprobe  

# Scan the ftp.acc.umu.se mirror
scanMirror ftp.acc.umu.se ZIMDIRS

# Scan the dotsrc.org mirror
scanMirror dotsrc.org ALLDIRS

# scan the Kiwix mirrors
scanMirror mirror ALLDIRS

# Scan Tunisian mirror
scanMirror mirror.tn ZIMDIRS

# Scan the Wikimedia mirror
scanMirror wikimedia WMDIRS

# Scan the ISOC Israel mirror
scanMirror isoc.il WMDIRS

# Scan the Your.org mirror
scanMirror your.org WMDIRS

# Scan the nluug.nl mirror
scanMirror nluug.nl ALLDIRS

# Scan the Mirrorservice.org mirror
scanMirror mirrorservice.org WMDIRS

# Scan the fau.de mirror
scanMirror fau.de ALLDIRS

# Generate HTML mirrors list
mb mirrorlist -f xhtml | grep -v "href=\"\"" > /var/www/download.kiwix.org/mirrors.html

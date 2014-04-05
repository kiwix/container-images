#!/bin/sh

DIRS="/ archive bin dev other portable src zim"

# Clean up the db
mb db vacuum > /dev/null 2>&1

# Build hash for new files in the master directory
mb makehashes /var/www/download.kiwix.org/ -t /usr/share/mirrorbrain > /dev/null 2>&1

# Check if mirrors are online
mirrorprobe > /dev/null 2>&1

# Scan the Wikimedia mirror
mb scan -d zim/0.9 wikimedia > /dev/null 2>&1
mb scan -d zim/wikipedia wikimedia > /dev/null 2>&1
mb scan -d zim/wikisource wikimedia > /dev/null 2>&1
mb scan -d zim/wikivoyage wikimedia > /dev/null 2>&1
mb scan -d zim/wiktionary wikimedia > /dev/null 2>&1
mb scan -d portable/wikipedia wikimedia > /dev/null 2>&1
mb scan -d portable/wikisource wikimedia > /dev/null 2>&1
mb scan -d portable/wikivoyage wikimedia > /dev/null 2>&1
mb scan -d portable/wiktionary wikimedia > /dev/null 2>&1

# Scan the ISOC Israel mirror
mb scan -d zim/0.9 isoc.il > /dev/null 2>&1
mb scan -d zim/other isoc.il > /dev/null 2>&1
mb scan -d zim/wikipedia isoc.il > /dev/null 2>&1
mb scan -d zim/wikisource isoc.il > /dev/null 2>&1
mb scan -d zim/wikivoyage isoc.il > /dev/null 2>&1
mb scan -d zim/wiktionary isoc.il > /dev/null 2>&1

# Scan the Your.org mirror
mb scan -d zim/wikipedia your.org > /dev/null 2>&1
mb scan -d zim/wikisource your.org > /dev/null 2>&1
mb scan -d zim/wikivoyage your.org > /dev/null 2>&1
mb scan -d zim/wiktionary your.org > /dev/null 2>&1
mb scan -d portable/wikipedia your.org > /dev/null 2>&1
mb scan -d portable/wikisource your.org > /dev/null 2>&1
mb scan -d portable/wikivoyage your.org > /dev/null 2>&1
mb scan -d portable/wiktionary your.org > /dev/null 2>&1

# Scan the Mirrorservice.org mirror
mb scan -d zim/wikipedia mirrorservice.org > /dev/null 2>&1
mb scan -d zim/wikisource mirrorservice.org > /dev/null 2>&1
mb scan -d zim/wikivoyage mirrorservice.org > /dev/null 2>&1
mb scan -d zim/wiktionary mirrorservice.org > /dev/null 2>&1
mb scan -d portable/wikipedia mirrorservice.org > /dev/null 2>&1
mb scan -d portable/wikisource mirrorservice.org > /dev/null 2>&1
mb scan -d portable/wikivoyage mirrorservice.org > /dev/null 2>&1
mb scan -d portable/wiktionary mirrorservice.org > /dev/null 2>&1

# scan the Kiwix first mirror
for DIR in $DIRS
do
    mb scan -d "$DIR" kiwix > /dev/null 2>&1
done

# scan the Kiwix second mirror
for DIR in $DIRS
do
    mb scan -d "$DIR" mirror2 > /dev/null 2>&1
done

# scan the Kiwix third mirror
for DIR in $DIRS
do
    mb scan -d "$DIR" mirror3 > /dev/null 2>&1
done

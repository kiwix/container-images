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

# Scan the ISOC Israel mirror
mb scan -d zim/0.9 isoc.il > /dev/null 2>&1

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

#!/bin/bash

REPO="/var/www/download.kiwix.org/"

# Build hash for new files in the master directory
echo "Building hash for new files..."
$MB makehashes $REPO -t /usr/share/mirrorbrain 

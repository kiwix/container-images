#!/bin/sh

BINARY=$0
BINARY_DIR=`pwd`/`dirname $BINARY`
DIR=/var/www/mirror/
LOCKFILE=$DIR/jobs.lock

# Check if the script is already running
if [ -e $LOCKFILE ]
then
    exit 1
fi

# Write the lock file
touch $LOCKFILE

# Change dir 
cd $DIR
for MIRROR in `ls -lad * | cut -d " " -f 8`
do
    echo $MIRROR
    STATUS=255

    while [ "$STATUS" -eq "255" ]
    do
	php $MIRROR/maintenance/runJobs.php >> /tmp/jobs.log
	STATUS=$?
    done
done

# Remove the lock file
rm $LOCKFILE
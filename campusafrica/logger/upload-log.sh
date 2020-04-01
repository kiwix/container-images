#!/bin/bash

# upload and process a single log file
#
# 1. parse+upload via matomo script
# 2. move and compress upon success
# 2. move and compress (different name) upon failure

source /etc/default/logger

if [ -z $1 ] || [ ! -f "$1" ]
then
    echo "No log file supplied or file missing, exiting."
    exit 1
fi

fpath=$1
folder=$(dirname $fpath)
fname=$(basename $fpath)
successdir=$folder/uploaded
errordir=$folder/errored
mkdir -p $successdir $errordir
ownlog=$errordir/${fname}_err.log
lockfile=${fpath}.lock

if [ -f $lockfile ]
then
    echo "Lock file $lockfile exists. assuming upload in progress, exiting."
    exit 1
fi

echo "Uploading log file $fpath to stats server"
touch $lockfile
import_logs.py --show-progress \
    --hostname="*${FQDN}" \
    --enable-http-redirects \
    --idsite="${MATOKO_SITE_ID}" \
    --url="${MATOMO_URL}" \
    --token-auth="${MATOMO_TOKEN}" \
    $fpath &> $ownlog
retcode=$?

if [ $retcode -eq 0 ]; then
    echo "Upload suceeded, archiving log file"
    rm -f $ownlog
    dest=$successdir/$fname
else
    echo "Upload failed. moving to error folder. Script output at $ownlog"
    dest=$errordir/$fname
fi
mv $fpath $dest && gzip --fast --force $dest
rm -f $lockfile

exit $retcode

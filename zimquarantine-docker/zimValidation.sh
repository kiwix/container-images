#/bin/bash
#
# Author : Florent Kaisser
#
# Usage : zimValidation <zimFilePath> <zimSrcDir> <zimDstDir> <zimQuarantineDir> <logDir> <zimCheckOptions> [NO_QUARANTINE|NO_CHECK]
#

ZIMCHECK=/usr/local/bin/zimcheck
ZIMFILE=$1
ZIMSRCDIR=$2

ZIMPATH=`echo $ZIMFILE | sed "s:$ZIMSRCDIR::"`

DESTFILE=$3$ZIMPATH
DESTDIR=`dirname $DESTFILE`

QUARFILE=$4$ZIMPATH
QUARDIR=`dirname $QUARFILE`

LOGFILE=$5$ZIMPATH
LOGDIR=`dirname $LOGFILE`

ZIMCHECK_OPTION=$6
OPTION=$7


function moveZim () {
   mkdir -p $1
   mv -f $ZIMFILE $2
}

if [ "$OPTION" = "NO_CHECK" ]
then
  echo "move $ZIMFILE to $DESTFILE"
  moveZim $DESTDIR $DESTFILE
else
  mkdir -p $LOGDIR
  if [ "$OPTION" = "NO_QUARANTINE" ] || $ZIMCHECK $ZIMCHECK_OPTION $ZIMFILE > $LOGFILE
  then
   echo "$ZIMFILE is valid, move to $DESTFILE"
   moveZim $DESTDIR $DESTFILE
  else
   echo "$ZIMFILE is not valid, quarantine to $QUARFILE"
   moveZim $QUARDIR $QUARFILE
  fi
fi

rm -f /tmp/zimcheckoutput

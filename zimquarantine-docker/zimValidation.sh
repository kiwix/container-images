ZIMPATH=`echo $1 | sed "s:$2::"`
ZIMFILE=$1
DESTFILE=$3$ZIMPATH
DESTDIR=`dirname $DESTFILE`

echo "=================================="

zimcheck -A $ZIMFILE | tee /tmp/zimcheckoutput

if grep -q 'Status: Pass' /tmp/zimcheckoutput
then
 echo "OK !!!"
else
 echo "NOT OK !!"
fi

#rm -f /tmp/zimcheckoutput

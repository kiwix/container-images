
echo "Generate library.kiwix.org.xml file"
manageLibraryKiwixOrg.pl --source=/data/download/library/library_zim.xml > library.kiwix.org.xml

service cron start

while [ 42 ] 
do 
  echo "Start kiwix-serve ..."
  kiwix-serve --port=80 --library --threads=16 --verbose library.kiwix.org.xml ; 
  sleep 1 ; 
done

ln -fs /var/www/download.kiwix.org/zim/ /var/www/library.kiwix.org/zim 

{ \
  echo "User-agent: *" ; \
  echo "Crawl-delay: 3" ; \
} > /var/www/library.kiwix.org/robots.txt

echo "Generate library.kiwix.org.xml file"
manageLibraryKiwixOrg.pl --source=/var/www/download.kiwix.org/library/library_zim.xml > library.kiwix.org.xml

service cron start

while [ 42 ] 
do 
  echo "Start kiwix-serve ..."
  kiwix-serve --port=80 --library --threads=16 --verbose library.kiwix.org.xml ; 
  sleep 1 ; 
done

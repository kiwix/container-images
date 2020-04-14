
{ \
  echo "User-agent: *" ; \
  echo "Crawl-delay: 3" ; \
} > /var/www/library.kiwix.org/robots.txt

{ \
  echo "#!/bin/sh" ; \
  echo "cd $LIBRARY_DIR" ; \
  echo "manageLibraryKiwixOrg.pl --source=/var/www/download.kiwix.org/library/library_zim.xml >library.kiwix.org.xml 2>>/dev/shm/libgen" ; \
  echo "kill \`pidof kiwix-serve\`" ; \
} > /etc/cron.daily/80generateLibraryKiwixOrg && chmod 0500 /etc/cron.daily/80generateLibraryKiwixOrg

{ \
  echo "#!/bin/sh" ; \
  echo "cd $LIBRARY_DIR" ; \
  echo "manageContentRepository.pl --writeWiki --writeRedirects --writeHtaccess --writeLibrary --deleteOutdatedFiles >>/dev/shm/libgen 2>&1" ; \
  echo "updateWikiPage.py wiki.kiwix.org LibraryBot `cat /run/secrets/wiki-password` 'Template:ZIMdumps/content' '/var/www/download.kiwix.org/zim/.contentPage.wiki' 'Automatic update of the ZIM library'" ; \
} > /etc/cron.daily/10updateContentRepository && chmod 0500 /etc/cron.daily/10updateContentRepository

echo "Generate library.kiwix.org.xml file"
manageLibraryKiwixOrg.pl --source=/var/www/download.kiwix.org/library/library_zim.xml > library.kiwix.org.xml

service cron start

while [ 42 ]
do
  echo "Start kiwix-serve ..."
  kiwix-serve --port=80 --library --threads=16 --verbose --nodatealias library.kiwix.org.xml
  sleep 1
done



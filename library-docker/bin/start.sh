#!/bin/bash

printf "
# User-agent: *
# Crawl-delay: 3
Disallow: /
" > /var/www/library.kiwix.org/robots.txt

printf "#!/bin/sh
/usr/sbin/varnishreload
echo 'ban req.url ~ "^.*$"' | /usr/bin/varnishadm -T localhost:6082 -S /etc/varnish/secret
" > /usr/local/bin/varnish-clear && chmod 0500 /usr/local/bin/varnish-clear

printf "#!/bin/sh
cd $LIBRARY_DIR
manageLibraryKiwixOrg.pl --source=/var/www/download.kiwix.org/library/library_zim.xml >library.kiwix.org.xml 2>>/dev/shm/libgen
" > /etc/cron.daily/80generateLibraryKiwixOrg && chmod 0500 /etc/cron.daily/80generateLibraryKiwixOrg

printf "#!/bin/sh
cd $LIBRARY_DIR
manageContentRepository.pl --writeWiki --writeRedirects --writeHtaccess --writeLibrary --deleteOutdatedFiles >>/dev/shm/libgen 2>&1
updateWikiPage.py wiki.kiwix.org LibraryBot `cat /run/secrets/wiki-password` 'Template:ZIMdumps/content' '/var/www/download.kiwix.org/zim/.contentPage.wiki' 'Automatic update of the ZIM library'
" > /etc/cron.daily/10updateContentRepository && chmod 0500 /etc/cron.daily/10updateContentRepository

echo "Generate library.kiwix.org.xml file"
manageLibraryKiwixOrg.pl --source=/var/www/download.kiwix.org/library/library_zim.xml > library.kiwix.org.xml

echo "Update crontab for kiwix-serve"
printf "
@reboot root /usr/local/bin/restart-kiwix-serve.sh restart
* * * * * root /usr/local/bin/restart-kiwix-serve.sh
" >> /etc/crontab

service cron start && crontab /etc/crontab

# record varnish secret if not on compose
if [ -f /run/secrets/varnish ]
then
  echo "missing secret, writting"
  cat /run/secrets/varnish > /etc/varnish/secret
else
  echo $VARNISH_SECRET > /etc/varnish/secret
fi

echo "Starting main command..."
exec "$@"

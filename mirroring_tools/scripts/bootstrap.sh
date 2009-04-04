#!/bin/sh

LANG=en

./resetMediawikiDatabase.pl --database=mirror_$LANG --dropDatabase --username=root --password=r00t

rm -rf /var/www/mirror/$LANG
./mirrorMediawikiCode.pl --host=$LANG.wikipedia.org --path=w --action=checkout --directory=/var/www/mirror/$LANG/

./installMediawiki.pl --directory=/var/www/mirror/$LANG/ --site=$LANG.mirror.localhost --code=$LANG --languageCode=$LANG --sysopUser=Kelson --sysopPassword=KelsonKelson --dbUser=root --dbPassword=r00t --confInclude=/var/www/mediawiki_commons/mirror_LocalSettings.php --confInclude=/var/www/mirror/$LANG/extensions.php

./mirrorMediawikiInterwikis.pl --destinationDatabase=mirror_$LANG --sourceHost=$LANG.wikipedia.org --sourcePath=w --destinationUsername=root --destinationPassword=r00t

echo -e '\nMediawiki:common.js\nMediawiki:common.css\nMediawiki:monobook.css\nMediawiki:monobook.js\n' | ./mirrorMediawikiPages.pl --sourceHost=$LANG.wikipedia.org --sourcePath=w --destinationHost=$LANG.mirror.localhost --destinationUsername=kelson --destinationPassword=KelsonKelson --readFromStdin
 
#!/bin/sh
cd /home/kelson/bin/stats/cgi-bin/
php ./fillPiwikWithWebServerLogs.php --idSite=2 --webUrl=https://download.kiwix.org --piwikUrl=https://stats.kiwix.org --tokenAuth=$1 --filter='^.*\.[a-z]{3,8}$' --followLog /var/log/nginx/download.kiwix.org.access.log*

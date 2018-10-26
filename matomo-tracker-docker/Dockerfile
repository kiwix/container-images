FROM php
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

RUN apt-get update && apt-get install -y --no-install-recommends git cron vim

RUN git clone --quiet --depth=1 https://github.com/matomo-org/matomo-php-tracker \ 
  && cd matomo-php-tracker \
  && mkdir -p  /usr/local/libs/PiwikTracker \
  && cp *.php /usr/local/libs/PiwikTracker/ 
  
COPY fillPiwikWithWebServerLogs_download.kiwix.org.sh /usr/local/bin/ 
COPY fillPiwikWithWebServerLogs.php /usr/local/bin/ 

RUN chmod a+x /usr/local/bin/* 

RUN { \
  echo "#!/bin/sh" ; \
  echo "cd /usr/local/bin && sh fillPiwikWithWebServerLogs_download.kiwix.org.sh" ; \
} > /etc/cron.hourly/matomo

CMD cron -f

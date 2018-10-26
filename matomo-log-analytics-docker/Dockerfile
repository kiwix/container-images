FROM php
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

WORKDIR /usr/local/libs

RUN apt-get update && apt-get install -y --no-install-recommends git cron vim python

RUN git clone --quiet --depth=1 https://github.com/matomo-org/matomo-log-analytics \
  && cp -vr matomo-log-analytics/*.py  /usr/local/bin/ \
  && chmod a+x /usr/local/bin/*.py 
    
#COPY fillPiwikWithWebServerLogs.php /usr/local/bin/ 

#RUN mkdir -p /usr/config && touch /usr/config/config.ini.php

CMD { \
  echo "#!/bin/sh" ; \
  echo "import_logs.py --idsite=$ID_SITE --url=$URL --token-auth=$TOKEN $LOG " ; \
} > /etc/cron.hourly/matomo && chmod a+x /etc/cron.hourly/matomo && cron -f



#import_logs.py --url=$URL --token-auth=$TOKEN  $LOG 

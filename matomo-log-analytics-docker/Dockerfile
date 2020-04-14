FROM debian:buster-slim

#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates unzip wget patch python2 cron && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/3.x-dev.zip https://github.com/matomo-org/matomo-log-analytics/archive/3.x-dev.zip && unzip -d /tmp /tmp/3.x-dev.zip && mv /tmp/matomo-log-analytics-3.x-dev/import_logs.py /usr/local/bin/ && chmod a+x /usr/local/bin/import_logs.py && rm -f /tmp/3.x-dev.zip && rm -rf /tmp/matomo-log-analytics-3.x-dev
COPY ignore_301.patch /tmp
RUN patch /usr/local/bin/import_logs.py < /tmp/ignore_301.patch && rm /tmp/ignore_301.patch

CMD { \
  echo "#!/bin/sh" ; \
  echo "import_logs.py --enable-http-redirects --include-host=$HOST --idsite=$ID_SITE --url=$URL --token-auth=`cat /run/secrets/matomo-token` $LOG" ; \
} > /etc/cron.hourly/matomo && chmod 700 /etc/cron.hourly/matomo && cron -f

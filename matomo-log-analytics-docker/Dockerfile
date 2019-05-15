FROM debian:stretch-slim
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

WORKDIR /usr/local/libs

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates cron python

RUN git clone --quiet --depth=1 https://github.com/matomo-org/matomo-log-analytics \
  && cp -vr matomo-log-analytics/*.py  /usr/local/bin/ \
  && chmod a+x /usr/local/bin/*.py

CMD { \
  echo "#!/bin/sh" ; \
  echo "import_logs.py --enable-http-redirects --include-host=$HOST --idsite=$ID_SITE --url=$URL --token-auth=`cat /run/secrets/matomo-token` $LOG" ; \
} > /etc/cron.hourly/matomo && chmod 700 /etc/cron.hourly/matomo && cron -f

FROM debian:buster-slim

#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates unzip wget patch python2 && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/3.x-dev.zip https://github.com/matomo-org/matomo-log-analytics/archive/3.x-dev.zip && unzip -d /tmp /tmp/3.x-dev.zip && mv /tmp/matomo-log-analytics-3.x-dev/import_logs.py /usr/local/bin/ && chmod a+x /usr/local/bin/import_logs.py && rm -f /tmp/3.x-dev.zip && rm -rf /tmp/matomo-log-analytics-3.x-dev
COPY ignore_301.patch /tmp
RUN patch /usr/local/bin/import_logs.py < /tmp/ignore_301.patch && rm /tmp/ignore_301.patch

ENV HOST "my-domain"
ENV MATOMO_URL "http://my-matomo"
ENV MATOMO_SITE_ID "0"
ENV MATOMO_TOKEN "abc"
ENV LOG_PATH "/var/log/nginx/access.log"

RUN { \
  echo "#!/bin/sh" ; \
  echo "import_logs.py --enable-http-redirects --include-host=$HOST --idsite=$MATOMO_SITE_ID --url=$MATOMO_URL --token-auth=$MATOMO_TOKEN $LOG_PATH" ; \
} > /usr/local/bin/import-log && chmod +x /usr/local/bin/import-log

CMD ["import-log"]

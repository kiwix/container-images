FROM debian:bookworm-slim
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates unzip wget patch python3 && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/5.x-dev.zip https://github.com/matomo-org/matomo-log-analytics/archive/5.x-dev.zip && unzip -d /tmp /tmp/5.x-dev.zip && mv /tmp/matomo-log-analytics-5.x-dev/import_logs.py /usr/local/bin/ && chmod a+x /usr/local/bin/import_logs.py && rm -f /tmp/3.x-dev.zip && rm -rf /tmp/matomo-log-analytics-3.x-dev
COPY ignore_301.patch /tmp
RUN patch /usr/local/bin/import_logs.py < /tmp/ignore_301.patch && rm /tmp/ignore_301.patch

ENV HOST "my-domain"
ENV MATOMO_URL "http://my-matomo"
ENV MATOMO_SITE_ID "0"
ENV MATOMO_TOKEN "abc"
ENV LOG_PATH "/var/log/nginx/access.log"
# enable to append today's date suffix to LOG_PATH (for use with logrotate's archive)
ENV USE_SUFFIXED_LOG ""

RUN { \
  echo '#!/bin/sh' ; \
  echo 'if [ ! -z "$USE_SUFFIXED_LOG" ] ; then' ; \
  echo '    export LOG_PATH=$LOG_PATH-$(date +"%Y%m%d")' ; \
  echo 'fi' ; \
  echo 'import_logs.py --useragent-exclude qbittorrent --useragent-exclude libtorrent \
  --useragent-exclude vuze --useragent-exclude deluge --useragent-exclude utorrent \
  --useragent-exclude bittorrent --useragent-exclude biglybt \
  --useragent-exclude bitcomet --useragent-exclude bitlord \
  --useragent-exclude frostwire --useragent-exclude kget \
  --useragent-exclude ktorrent --useragent-exclude limewire \
  --useragent-exclude mldonkey --useragent-exclude rtorrent \
  --useragent-exclude robert --useragent-exclude shareaza --useragent-exclude tixati \
  --useragent-exclude tonido --useragent-exclude transmission \
  --useragent-exclude tribler --useragent-exclude xunlei \
  --enable-http-redirects --include-host=$HOST --idsite=$MATOMO_SITE_ID --url=$MATOMO_URL --token-auth=$MATOMO_TOKEN $LOG_PATH' ; \
} > /usr/local/bin/import-log && chmod +x /usr/local/bin/import-log

CMD ["import-log"]

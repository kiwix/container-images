FROM debian:buster-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates unzip wget patch python2 logrotate

RUN wget -O /tmp/3.x-dev.zip https://github.com/matomo-org/matomo-log-analytics/archive/3.x-dev.zip && unzip -d /tmp /tmp/3.x-dev.zip && mv /tmp/matomo-log-analytics-3.x-dev/import_logs.py /usr/local/bin/ && chmod a+x /usr/local/bin/import_logs.py && rm -f /tmp/3.x-dev.zip && rm -rf /tmp/matomo-log-analytics-3.x-dev
COPY format_and_exit.patch /tmp
RUN patch /usr/local/bin/import_logs.py < /tmp/format_and_exit.patch && rm /tmp/format_and_exit.patch

RUN ln -s /usr/bin/python2 /usr/bin/python
RUN wget https://bootstrap.pypa.io/get-pip.py -O get-pip.py && python get-pip.py && rm get-pip.py && pip install docker==4.2.0

COPY reload-nginx.py /usr/local/bin/reload-nginx
RUN chmod +x /usr/local/bin/reload-nginx

COPY upload-log.sh /usr/local/bin/upload-log
RUN chmod +x /usr/local/bin/upload-log

COPY upload-logs.py /usr/local/bin/upload-logs
RUN chmod +x /usr/local/bin/upload-logs

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]

ENV LOG_FOLDER /data/logs
ENV NGINX_CONTAINER reverse-proxy
ENV FQDN not-set.tld
ENV MATOMO_URL http://matomo.tld
ENV MATOKO_SITE_ID not-set
ENV MATOMO_TOKEN not-set

CMD ["cron", "-f"]

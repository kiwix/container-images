FROM jwilder/nginx-proxy

RUN apt-get update && apt-get install -y --no-install-recommends cron logrotate

RUN usermod -a -G users nginx

RUN { \
    echo "include /etc/nginx/sites-enabled/*;" ; \
} > /etc/nginx/conf.d/10sites_alias.conf

RUN { \
    echo "limit_req_zone \$binary_remote_addr zone=limit:10m rate=50r/s;" ; \
} > /etc/nginx/conf.d/00limit.conf

RUN { \
    echo "gzip on;" ; \
    echo "gzip_proxied any;" ; \
    echo "gzip_types application/rss+xml application/opensearchdescription+xml image/svg+xml application/vnd.ms-fontobject application/x-font-ttf font/opentype application/atom+xml text/yaml text/tab-separated-values;" ; \
} > /etc/nginx/conf.d/05gzip.conf

RUN sed -i '4i \    text/yaml                                        yml;' /etc/nginx/mime.types

RUN mkdir /etc/nginx/maps
RUN touch /etc/nginx/maps/wp1.map

COPY sites/* /etc/nginx/sites-enabled/

COPY 10createWp1Redirects /etc/cron.hourly/

COPY docker-entrypoint.sh /app/
RUN chmod a+x docker-entrypoint.sh

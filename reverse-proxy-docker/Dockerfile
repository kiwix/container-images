FROM jwilder/nginx-proxy

RUN apt-get update && apt-get install -y --no-install-recommends cron logrotate python3 curl patch

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

# download and patch genRSS
RUN curl "https://raw.githubusercontent.com/amsehili/genRSS/5c238fca244b0067fcc0d10b26506ef5d8eca804/genRSS.py" > /usr/local/bin/genRSS.py
COPY genrss.patch /tmp/genrss.patch
RUN patch /usr/local/bin/genRSS.py < /tmp/genrss.patch && rm /tmp/genrss.patch
RUN chmod +x /usr/local/bin/genRSS.py

RUN mkdir /etc/nginx/maps
RUN touch /etc/nginx/maps/wp1.map

COPY sites/* /etc/nginx/sites-enabled/

COPY 10createWp1Redirects /etc/cron.hourly/
COPY 12createReleaseFeeds /etc/cron.hourly/

COPY docker-entrypoint.sh /app/
RUN chmod a+x docker-entrypoint.sh

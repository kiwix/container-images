FROM jwilder/nginx-proxy

RUN apt-get update && apt-get install -y --no-install-recommends cron 

RUN { \
    echo "include /etc/nginx/sites-enabled/*;" ; \
} > /etc/nginx/conf.d/10sites_alias.conf

RUN { \
    echo "limit_req_zone \$binary_remote_addr zone=limit:10m rate=3r/s;" ; \
} > /etc/nginx/conf.d/00limit.conf

COPY sites/* /etc/nginx/sites-enabled/

COPY docker-entrypoint.sh /app/ 
RUN chmod a+x docker-entrypoint.sh

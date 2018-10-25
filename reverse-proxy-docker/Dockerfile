FROM jwilder/nginx-proxy
RUN { \
    echo "include /etc/nginx/sites-enabled/*;" ; \
} > /etc/nginx/conf.d/sites_alias.conf
COPY sites/* /etc/nginx/sites-enabled/


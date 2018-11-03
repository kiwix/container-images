FROM jwilder/nginx-proxy
RUN { \
    echo "include /etc/nginx/sites-enabled/*;" ; \
} > /etc/nginx/conf.d/00sites_alias.conf
COPY sites/* /etc/nginx/sites-enabled/

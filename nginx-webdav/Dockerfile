FROM debian:bookworm-slim

COPY custom.conf /etc/nginx/snippets/custom.conf
COPY webdav.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /usr/local/bin/entrypoint

RUN \
    apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y dumb-init curl \
    # nginx and its plugins for webdav and fancyindex
        nginx nginx-extras libnginx-mod-http-dav-ext libnginx-mod-http-auth-pam libnginx-mod-http-fancyindex \
    # apache2-utils to create htpasswd from ENVIRON in entrypoint
        apache2-utils \
    && rm /etc/nginx/sites-enabled/* \
    && mkdir -p /var/www/fancyindex-themes \
    # fancyindex them
    && curl -L -o /tmp/theme.tar.gz https://github.com/alehaa/nginx-fancyindex-flat-theme/releases/download/v1.2/nginx-fancyindex-flat-theme-1.2.tar.gz \
    && tar -C /var/www/fancyindex-themes/ --strip-components 1 -x -f /tmp/theme.tar.gz \
    # another theme
    # && curl -L -o /tmp/theme.tar.gz https://github.com/fraoustin/Nginx-Fancyindex-Theme/archive/refs/tags/0.1.7.tar.gz \
    # && tar -C /var/www/fancyindex-themes/ --strip-components 1 -x -f /tmp/theme.tar.gz \
    && mkdir -p "/data" \
    && chown -R www-data:www-data /data \
    && chmod +x /usr/local/bin/entrypoint

WORKDIR /data
VOLUME /data
EXPOSE 80
ENV USERNAME ""
ENV PASSWORD ""
ENV NAME ""

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint" , "nginx", "-g", "daemon off;"]

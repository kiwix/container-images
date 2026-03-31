FROM caddy:2.11-alpine

LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

COPY src/ /usr/share/caddy/

COPY Caddyfile /etc/caddy/Caddyfile

EXPOSE 80

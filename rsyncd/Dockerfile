FROM docker.io/library/alpine:3.23
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

RUN \
    echo 'http://dl-cdn.alpinelinux.org/alpine/v3.19/main' >> /etc/apk/repositories \
    && apk update \
    && apk add --no-cache rsync=3.4.1-r1 \
    && mkdir -m 644 -p /var/rsync/pub \
    && chown 33:33 /var/rsync/pub \
    && printf "\
 █████   ████    █████    █████   ███   █████    █████    █████ █████\n\
░░███   ███░    ░░███    ░░███   ░███  ░░███    ░░███    ░░███ ░░███ \n\
 ░███  ███       ░███     ░███   ░███   ░███     ░███     ░░███ ███  \n\
 ░███████        ░███     ░███   ░███   ░███     ░███      ░░█████   \n\
 ░███░░███       ░███     ░░███  █████  ███      ░███       ███░███  \n\
 ░███ ░░███      ░███      ░░░█████░█████░       ░███      ███ ░░███ \n\
 █████ ░░████    █████       ░░███ ░░███         █████    █████ █████\n\
░░░░░   ░░░░    ░░░░░         ░░░   ░░░         ░░░░░    ░░░░░ ░░░░░ \n\
\n\
\n\
"> /var/rsync/motd \
    && printf "\
[global]\n\
charset = utf-8\n\
log file = /dev/stdout\n\
motd file = /var/rsync/motd\n\
\n\
# alpine-based image have xfs user on uid 33 and xfa group on gid 33\n\
# which corresponds to www-data/www-data on debian\n\
numeric ids = yes\n\
# allow enough time for --list-only on whole thing (20m)\n\
timeout = 1200\n\
\n\
list = yes\n\
uid = 33\n\
gid = 33\n\
read only = true\n\
\n\
dont compress = *.zim *.gz *.xz *.bz2 *.zip *.img\n\
\n\
# [zim]\n\
# list = yes\n\
# path = /var/rsync/pub/zim\n\
# comment = openZIM Catalog\n\
# max connections = 1\n\
# lock file = /var/lock/rsync_zim_module.lock\n\
# hosts allow = 100.64.0.0/15\n\
\n\
" > /etc/rsyncd.conf

VOLUME /var/rsync/pub
EXPOSE 873

CMD ["/usr/bin/rsync", "--daemon", "--no-detach", "--log-file", "/dev/stdout", "--config=/etc/rsyncd.conf"]

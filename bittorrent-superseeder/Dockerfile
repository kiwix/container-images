FROM debian:buster-slim

MAINTAINER Emmanuel Engelhart <kelson@kiwix.org>

WORKDIR /tmp

# All-in-One RUN for a very small image size (< 5 MB)
RUN apt update 2> /dev/null && \
    apt install -y --no-install-recommends apt-transport-https curl gnupg ca-certificates cron gron xml2 && \

    curl -fsSL 'https://dl.cloudsmith.io/public/qbittorrent-cli/qbittorrent-cli/gpg.F8756541ADDA2B7D.key' | apt-key add - && \
    curl "https://repos.fedarovich.com/debian/buster/qbittorrent-cli.list" --output /etc/apt/sources.list.d/qbittorrent-cli.list && \
    apt update && \
    apt install -y --no-install-recommends qbittorrent-cli && \

    apt remove -y --purge gnupg && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*


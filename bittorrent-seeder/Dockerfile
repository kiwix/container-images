FROM alpine:edge

ENV SHELL=bash

RUN set -e \
    # add testing repo for qbittorrent-cli
    && echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && apk update \
    && apk --no-cache add dumb-init bash \
    && apk --no-cache add python3 py3-pip \
    # the daemon with webui \
    && apk --no-cache add qbittorrent-nox \
    # for convenience
    && apk --no-cache add qbittorrent-cli

ENV NO_DAEMON=""
ENV QBT_TORRENTING_PORT=6901
ENV QBT_HOST=localhost
ENV QBT_PORT=80
ENV QBT_USERNAME=admin
ENV QBT_PASSWORD=


COPY entrypoint.sh /usr/local/bin/entrypoint
COPY pyproject.toml README.md tasks.py /src/
COPY src/ /src/src
COPY gen-password.py /usr/local/bin/gen-password
COPY get-pbkdf2.py /usr/local/bin/get-pbkdf2

RUN set -e \
    && pip install --break-system-packages /src/ \
    && kiwix-seeder --help

EXPOSE 80
EXPOSE 6901
VOLUME /data
WORKDIR /data

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/entrypoint"]
CMD ["kiwix-seeder", "--loop"]

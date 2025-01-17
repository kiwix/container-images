FROM python:3.12-slim-bookworm
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

ENV SHELL=bash

RUN set -e \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        dumb-init curl apt-transport-https ca-certificates gnupg2 \
    # the daemon with webui \
    && curl -L -o /usr/bin/qbittorrent-nox https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.0.3_v2.0.10/x86_64-qbittorrent-nox \
    && chmod +x /usr/bin/qbittorrent-nox \
    && curl -L -o monit.tar.gz https://mmonit.com/monit/dist/binary/5.34.4/monit-5.34.4-linux-x64.tar.gz \
    && tar xf monit.tar.gz \
    && mv monit-5.34.4/bin/monit /usr/bin/monit \
    && rm -rf monit.tar.gz monit-5.34.4 \
    # for convenience (qBittorrent-cli)
    && curl -L https://dl.cloudsmith.io/public/qbittorrent-cli/qbittorrent-cli/gpg.F8756541ADDA2B7D.key | apt-key add - \
    && curl -L -o /etc/apt/sources.list.d/qbittorrent-cli.list https://repos.fedarovich.com/debian/bookworm/qbittorrent-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends qbittorrent-cli

ENV NO_QBT=""
ENV QBT_TORRENTING_PORT=6901
ENV QBT_HOST=localhost
ENV QBT_PORT=80
ENV QBT_USERNAME=admin
ENV QBT_PASSWORD=

ENV QBT_MAX_CONNECTIONS=500
ENV QBT_MAX_CONNECTIONS_PER_TORRENT=100
ENV QBT_MAX_UPLOADS=20
ENV QBT_MAX_UPLOADS_PER_TORRENT=5
ENV QBT_MAX_ACTIVE_CHECKING_TORRENTS=1

# pyproject.toml and its dependencies
COPY README.md /src/
COPY pyproject.toml README.md tasks.py /src/
COPY src/kiwixseeder/__about__.py /src/src/kiwixseeder/__about__.py
# install python dependencies
RUN pip install --no-cache-dir --break-system-packages /src/

COPY src/ /src/src
RUN set -e \
    && pip install --break-system-packages /src/ \
    && kiwix-seeder --help

COPY entrypoint.sh /usr/local/bin/entrypoint
COPY gen-password.py /usr/local/bin/gen-password
COPY get-pbkdf2.py /usr/local/bin/get-pbkdf2

EXPOSE 80
EXPOSE 6901
VOLUME /root/.config/qBittorrent
VOLUME /root/.local/share/qBittorrent
VOLUME /data
WORKDIR /data

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/entrypoint"]
CMD ["kiwix-seeder-loop"]

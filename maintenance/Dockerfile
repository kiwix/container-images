
FROM docker.io/library/python:3.11-slim-bookworm
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

# debian-slim based python container with libzim

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        locales \
        vim \
        cron \
        libmagic1 \
        curl \
        openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /scripts \
    && curl -sLo /sbin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 \
    && chmod +x /sbin/dumb-init \
    && mkdir -p /data

ENV TZ "UTC"
RUN echo "UTC" >  /etc/timezone \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

VOLUME /data

RUN pip install --no-cache-dir -U \
        "zimscraperlib==3.1.1" "unidecode==1.3.7" "mwclient==0.10.1" "humanfriendly==10.0" \
        "pyyaml==6.0.1" "pycountry==22.3.5" "jinja2==3.1.2" && \
    printf "#!/bin/bash\n\n\
set -e\n\
\
# install scripts and pydeps from ENV\n\
/usr/sbin/install-scripts\n\n\
\
# make sure all scripts (installed and mounted) are executable\n\
chmod +x /usr/local/bin/* 2> /dev/null\n\n\
\
# run startup script if present\n\
if [ -f /usr/local/bin/startup ]; then\n\
    echo \"Launching startup script…\"\n\
    /usr/local/bin/startup || exit \$?\n\
fi\n\n\
\
echo \"starting…\"\n\
exec \"\$@\"" > /sbin/entrypoint && chmod +x /sbin/entrypoint

ARG KUBECTL_VERSION="1.28.3"

RUN curl -sLo /usr/bin/kubectl \
    "https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl" && \
    chmod +x /usr/bin/kubectl

COPY install_scripts.py /usr/sbin/install-scripts
ENV INSTALL_SCRIPTS_TO /usr/local/bin
ENV INSTALL_SCRIPTS ""
ENV PIP_INSTALL ""

ENTRYPOINT ["dumb-init", "--", "entrypoint"]
CMD ["cron", "-f"]


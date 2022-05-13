FROM debian:buster-slim
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

MAINTAINER Emmanuel Engelhart <kelson@kiwix.org>

WORKDIR /tmp

# All-in-One RUN for a very small image size (< 5 MB)
RUN apt update 2> /dev/null && \
    apt install -y --no-install-recommends ca-certificates gcc g++ make git cvs cron xml2 zlib1g-dev curl unzip && \

    curl -SLO https://github.com/Yelp/dumb-init/archive/refs/tags/v1.2.5.zip && \
    unzip v1.2.5.zip && cd dumb-init-1.2.5 && make && \
    mv dumb-init /usr/bin/dumb-init && cd - && rm -rf ./dumb-init-1.2.5 && \

    cvs -d :pserver:cvs@cvs.fefe.de:/cvs -z9 co libowfat && \
    cd libowfat && \
    make && \
    cd ../ && \

    git clone git://erdgeist.org/opentracker && \
    cd opentracker && \
    for feature in COMPRESSION_GZIP ACCESSLIST_WHITE IP_FROM_QUERY_STRING IP_FROM_PROXY ; \
    do pattern="#FEATURES+=-DWANT_${feature}" ; sed -i -e "/${pattern}/s/^#//g" Makefile ; done && \
    make && \

    rm -rf /tmp/libowfat && \
    mv /tmp/opentracker/opentracker /bin/ && \
    mkdir -p /etc/opentracker/ && \
    touch /etc/opentracker/whitelist.txt && \

    apt remove -y --purge gcc g++ make git cvs zlib1g-dev unzip && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

COPY ./build_whitelist.sh /etc/cron.hourly/build_whitelist.sh
COPY ./entrypoint.sh /usr/sbin/entrypoint

EXPOSE 6969

ENTRYPOINT ["/usr/bin/dumb-init", "--", "entrypoint"]
CMD ["opentracker", "-r", "https://kiwix.org", "-w", "/etc/opentracker/whitelist.txt"]

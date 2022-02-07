FROM debian:buster-slim

MAINTAINER Emmanuel Engelhart <kelson@kiwix.org>

WORKDIR /tmp

# All-in-One RUN for a very small image size (< 5 MB)
RUN apt update 2> /dev/null && \
    apt install -y --no-install-recommends ca-certificates gcc g++ make git cvs cron xml2 zlib1g-dev curl && \

    cvs -d :pserver:cvs@cvs.fefe.de:/cvs -z9 co libowfat && \
    cd libowfat && \
    make && \
    cd ../ && \

    git clone git://erdgeist.org/opentracker && \
    cd opentracker && \
    make && \

    mv /tmp/opentracker/opentracker /bin/ && \

    apt remove -y --purge gcc g++ make git cvs zlib1g-dev && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

COPY ./opentracker.conf /etc/opentracker/opentracker.conf
COPY ./whitelist.txt /etc/opentracker/whitelist.txt
COPY ./blacklist.txt /etc/opentracker/blacklist.conf
COPY ./build_whitelist.sh /etc/cron.hourly/build_whitelist.sh
COPY ./start.sh /start.sh

EXPOSE 6969

CMD /start.sh

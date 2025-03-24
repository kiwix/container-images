FROM matomo:5.3.1-fpm
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

ENV LIBMMDBVERSION 1.7.1
ENV MMDBREADERVERSION 1.11.0

# install libmaxmindb for GeoIP2
RUN curl -L -o /tmp/libmaxminddb-$LIBMMDBVERSION.tar.gz \
    https://github.com/maxmind/libmaxminddb/releases/download/$LIBMMDBVERSION/libmaxminddb-$LIBMMDBVERSION.tar.gz && \
    tar -C /tmp/ -xf /tmp/libmaxminddb-$LIBMMDBVERSION.tar.gz && \
    cd /tmp/libmaxminddb-$LIBMMDBVERSION && ./configure && make && make install && ldconfig && \
    cd - && rm -rf /tmp/libmaxminddb-$LIBMMDBVERSION && \
    curl -L -o /tmp/MaxMind-DB-Reader-php-$MMDBREADERVERSION.tar.gz \
    https://github.com/maxmind/MaxMind-DB-Reader-php/archive/refs/tags/v$MMDBREADERVERSION.tar.gz && \
    tar -C /tmp -xf /tmp/MaxMind-DB-Reader-php-$MMDBREADERVERSION.tar.gz && \
    cd /tmp/MaxMind-DB-Reader-php-$MMDBREADERVERSION/ext && phpize && ./configure && \
    make && make install && docker-php-ext-enable maxminddb


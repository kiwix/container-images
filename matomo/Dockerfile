FROM matomo:5.14.0-fpm
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

ENV LIBMMDBVERSION 1.7.1
ENV MMDBREADERVERSION 1.11.0

# install libmaxmindb for GeoIP2
RUN \
    # install nginx in image (limited impact) so it can be used as reverse-proxy
    apt update && apt install -y nginx \
    && curl -L -o /tmp/libmaxminddb-$LIBMMDBVERSION.tar.gz https://github.com/maxmind/libmaxminddb/releases/download/$LIBMMDBVERSION/libmaxminddb-$LIBMMDBVERSION.tar.gz \
    && tar -C /tmp/ -xf /tmp/libmaxminddb-$LIBMMDBVERSION.tar.gz \
    && cd /tmp/libmaxminddb-$LIBMMDBVERSION \
    && ./configure && make && make install && ldconfig \
    && cd - && rm -rf /tmp/libmaxminddb-$LIBMMDBVERSION \
    && curl -L -o /tmp/MaxMind-DB-Reader-php-$MMDBREADERVERSION.tar.gz https://github.com/maxmind/MaxMind-DB-Reader-php/archive/refs/tags/v$MMDBREADERVERSION.tar.gz \
    && tar -C /tmp -xf /tmp/MaxMind-DB-Reader-php-$MMDBREADERVERSION.tar.gz \
    && cd /tmp/MaxMind-DB-Reader-php-$MMDBREADERVERSION/ext \
    && phpize && ./configure && make && make install \
    && docker-php-ext-enable maxminddb \
    # [TEMP] use kiwix fork of device-detector
    && curl -L -o /tmp/device-detector.tar.gz https://github.com/kiwix/device-detector/archive/refs/heads/master.tar.gz \
    && tar -C /tmp/ -xf /tmp/device-detector.tar.gz \
    && rm -rf /usr/src/matomo/vendor/matomo/device-detector/ \
    && mv /tmp/device-detector-master/ /usr/src/matomo/vendor/matomo/device-detector \
    && curl -L -o /tmp/matomo-icons.tar.gz https://github.com/kiwix/matomo-icons/archive/refs/heads/master.tar.gz \
    && tar -C /tmp/ -xf /tmp/matomo-icons.tar.gz \
    && rm -rf /usr/src/matomo/plugins/Morpheus/icons/dist \
    && mv /tmp/matomo-icons-master/dist /usr/src/matomo/plugins/Morpheus/icons/dist

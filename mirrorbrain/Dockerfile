FROM httpd:2.4.62
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images
LABEL maintainer="kiwix"

#Set software versions
ENV MB_VERSION 3.0.0

ENV LIBMAXMINDDB_VERSION 1.11.0
ENV MOD_MAXMINDDB_VERSION 1.2.0
ENV GEOIPUPDATE_VERSION 7.0.1
ENV GEOIPUPDATE_ARCH amd64

#Install needed packages
RUN mkdir -p /usr/share/man/man1/ /usr/share/man/man7/ &&  apt-get update && apt-get install -y --no-install-recommends wget cron automake libtool unzip  libaprutil1-dbd-pgsql postgresql-client build-essential libz-dev libconfig-inifiles-perl libwww-perl libdbd-pg-perl libtimedate-perl libdigest-md4-perl libaprutil1-dev python3-setuptools python3-pip python3-sqlobject python3-psycopg2 python3-pip python3-dev python3-geoip2 rsync
#Install cmdln manually since it is not packaged
RUN pip install --no-cache-dir --break-system-packages cmdln

#Copy owned base config file for apache
COPY config/apache/httpd.conf conf/httpd.conf

#Install Geolocalisation
RUN \
  cd /tmp && \
  wget -q -O libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VERSION}/libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz && \
  tar xzf libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz -C /usr/local/src && \
  rm libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz && \
  cd /usr/local/src/libmaxminddb-${LIBMAXMINDDB_VERSION} && \
  ./configure && \
  make && \
  make check && \
  make install && \
  ldconfig && \
  cd /tmp && \
  wget -q -O geoipupdate_${GEOIPUPDATE_VERSION}_linux_${GEOIPUPDATE_ARCH}.deb https://github.com/maxmind/geoipupdate/releases/download/v${GEOIPUPDATE_VERSION}/geoipupdate_${GEOIPUPDATE_VERSION}_linux_${GEOIPUPDATE_ARCH}.deb && \
  apt-get install -y ./geoipupdate_${GEOIPUPDATE_VERSION}_linux_${GEOIPUPDATE_ARCH}.deb && \
  rm /tmp/geoipupdate_${GEOIPUPDATE_VERSION}_linux_${GEOIPUPDATE_ARCH}.deb && \
  cd /tmp && \
  wget -q -O mod_maxminddb-${MOD_MAXMINDDB_VERSION}.tar.gz https://github.com/maxmind/mod_maxminddb/releases/download/${MOD_MAXMINDDB_VERSION}/mod_maxminddb-${MOD_MAXMINDDB_VERSION}.tar.gz && \
  tar xzf mod_maxminddb-${MOD_MAXMINDDB_VERSION}.tar.gz -C /usr/local/src && \
  rm mod_maxminddb-${MOD_MAXMINDDB_VERSION}.tar.gz && \
  cd /usr/local/src/mod_maxminddb-${MOD_MAXMINDDB_VERSION} && \
  ./configure && \
  make install

#Install MirrorBrain from sources
RUN \
  wget --no-check-certificate -qO - https://github.com/kiwix/mirrorbrain/archive/refs/tags/$MB_VERSION.tar.gz | tar -xz && \
  cd mirrorbrain-$MB_VERSION/mod_mirrorbrain && \
  wget -q http://apache.webthing.com/svn/apache/forms/mod_form.h && \
  wget -q http://apache.webthing.com/svn/apache/forms/mod_form.c && \
  apxs -cia -lm mod_form.c && \
  apxs -e -n dbd -a modules/mod_dbd.so && \
  apxs -e -n rewrite -a modules/mod_rewrite.so && \
  apxs -cia -lm mod_mirrorbrain.c && \
  cd ../mod_autoindex_mb && \
  apxs -cia mod_autoindex_mb.c && \
  cd ../tools && \
  install -m 755 null-rsync            /usr/bin/null-rsync && \
  install -m 755 scanner.pl            /usr/bin/scanner && \
  cd ../mirrorprobe/ && install -m 755 mirrorprobe.py  /usr/bin/mirrorprobe && \
  cd ../zsync/ && pip install --no-cache-dir --break-system-packages . && \
  cd ../mb && pip install --no-cache-dir --break-system-packages . && \
  cd ../assets && \
  mkdir -p /var/www/static/flags && \
  cp famfamfam_flag_icons/png/*.png /var/www/static/flags && \
  cp mirrorbrain.css /var/www/static

#Copy files configuration
RUN groupadd -r mirrorbrain && useradd -r -g mirrorbrain -s /bin/bash -c "MirrorBrain user" -d /home/mirrorbrain mirrorbrain
COPY config/mirrorbrain/mirrorbrain.conf /etc/
RUN chmod 0640 /etc/mirrorbrain.conf &&  chown root:mirrorbrain /etc/mirrorbrain.conf && mkdir /var/log/mirrorbrain/
COPY config/apache/httpd-vhosts.conf conf/extra/httpd-vhosts.conf

#Copy SQL dumps
# COPY ./sql/* mirrorbrain-$MB_VERSION/sql/

#Install start script
COPY bin/* /usr/local/bin/
RUN chmod 0500 /usr/local/bin/*
# Hack: change scanner variable $gig2 from 2GiB to 8EiB
# to completely disable the HTTP check
# this is used as a threshold on rsync scans
# Files larger than it trigger a Range-Request HTTP download.
# If the request fails a warning is printed
# Those requests are not necessary and create load on mirrors
RUN sed -i 's/gig2 = 1<<31;/gig2 = 1<<63; # HACKED --/' /usr/bin/scanner

#Start !
CMD ["start.sh"]

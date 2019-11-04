FROM httpd
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
# Based on instructions from https://mirrorbrain.org/docs/installation/source/
#
LABEL maintainer="kiwix"

#Set software versions
ENV MB_VERSION 2.18.1
ENV GEOIP_VERSION 1.6.12
ENV MOD_GEOPIP_VERSION 1.2.10

#Install needed packages
RUN mkdir -p /usr/share/man/man1/ /usr/share/man/man7/ &&  apt-get update && apt-get install -y --no-install-recommends wget cron automake libtool unzip  libaprutil1-dbd-pgsql postgresql-client build-essential libz-dev python python-dev python-pip python-setuptools python-sqlobject python-formencode python-psycopg2 libconfig-inifiles-perl libwww-perl libdbd-pg-perl libtimedate-perl libdigest-md4-perl 
RUN pip install cmdln

#Copy owned base config file for apache
COPY config/apache/httpd.conf conf/httpd.conf

#Install Geolocalisation
RUN { \
  cd /tmp ; \
  wget -q -O GeoIP-$GEOIP_VERSION.tar.gz  https://github.com/maxmind/geoip-api-c/releases/download/v$GEOIP_VERSION/GeoIP-$GEOIP_VERSION.tar.gz && \
  tar xzf GeoIP-$GEOIP_VERSION.tar.gz -C /usr/local/src && \
  cd /usr/local/src/GeoIP-$GEOIP_VERSION/ &&  \
  aclocal && autoconf && automake --add-missing && ./configure --prefix=/usr/local/geoip && make && make install ; \
  cd /tmp ; \
  mkdir -p /usr/local/geoip/share/GeoIP/ ; \
#  wget -q https://geolite.maxmind.com/download/geoip/database/GeoLite2-City-CSV.zip && \
#  unzip GeoLite2-City-CSV.zip  && cp GeoLite2-City-*/*.csv /usr/local/geoip/share/GeoIP/ && rm -rf GeoLite2-City-* ; \
#  wget -q https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country-CSV.zip && \
#  unzip GeoLite2-Country-CSV.zip && cp GeoLite2-Country-*/*.csv /usr/local/geoip/share/GeoIP/ && rm -rf GeoLite2-Country-* ; \
}

#Install Geolocalisation for Apache
RUN { \
  cd /tmp ; \
  wget -q -O mod_geoip2.tar.gz  https://github.com/maxmind/geoip-api-mod_geoip2/archive/$MOD_GEOPIP_VERSION.tar.gz && \
  tar xzf mod_geoip2.tar.gz -C /usr/local/src && \
  cd /usr/local/src/geoip-api-mod_geoip2-$MOD_GEOPIP_VERSION/ && \
  sed s/remote_ip/client_ip/g  -i  mod_geoip.c && \
  apxs -i -a -L/usr/local/geoip/lib -I/usr/local/geoip/include -lGeoIP -c mod_geoip.c ; \
}

#Install MirrorBrain from sources
COPY patch/mod_form.c mod_form.c.patch
RUN { \
  wget --no-check-certificate -qO - https://mirrorbrain.org/files/releases/mirrorbrain-$MB_VERSION.tar.gz | tar -xz ; \
  cd mirrorbrain-$MB_VERSION/mod_mirrorbrain ; \
  wget -q http://apache.webthing.com/svn/apache/forms/mod_form.h ; \
  wget -q http://apache.webthing.com/svn/apache/forms/mod_form.c ; \
  mv ../../mod_form.c.patch ./ ; \
  apxs -cia -lm mod_form.c ; \
  apxs -e -n dbd -a modules/mod_dbd.so ; \
  apxs -e -n rewrite -a modules/mod_rewrite.so ; \
  apxs -cia -lm mod_mirrorbrain.c ; \
  cd ../mod_autoindex_mb ; \
  apxs -cia mod_autoindex_mb.c ; \
  cd ../tools ; \
  gcc -Wall -o geoiplookup_continent geoiplookup_continent.c -L/usr/local/geoip/lib -I/usr/local/geoip/include -lGeoIP ; \
  gcc -Wall -o geoiplookup_city geoiplookup_city.c -L/usr/local/geoip/lib -I/usr/local/geoip/include -lGeoIP ; \
  install -m 755 geoiplookup_continent /usr/bin/geoiplookup_continent ; \
  install -m 755 geoiplookup_city      /usr/bin/geoiplookup_city ; \
  install -m 755 geoip-lite-update     /usr/bin/geoip-lite-update ; \
  install -m 755 tnull-rsync            /usr/bin/null-rsync ; \
  install -m 755 scanner.pl            /usr/bin/scanner ; \
  cd ../mirrorprobe/ && install -m 755 mirrorprobe.py  /usr/bin/mirrorprobe ; \
  cd ../mb && python setup.py install ; \
}

#Copy files configuration
RUN groupadd -r mirrorbrain && useradd -r -g mirrorbrain -s /bin/bash -c "MirrorBrain user" -d /home/mirrorbrain mirrorbrain
COPY config/mirrorbrain/mirrorbrain.conf /etc/
RUN chmod 0640 /etc/mirrorbrain.conf &&  chown root:mirrorbrain /etc/mirrorbrain.conf && mkdir /var/log/mirrorbrain/
COPY config/apache/httpd-vhosts.conf conf/extra/httpd-vhosts.conf

#Copy SQL dumps
COPY ./sql/* mirrorbrain-$MB_VERSION/sql/

#Install start script
COPY bin/* /usr/local/bin/
RUN chmod 0500 /usr/local/bin/*

#Start !
CMD start.sh

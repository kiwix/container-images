FROM httpd:2.4

#Install needed packages
RUN { \
  echo "deb http://download.opensuse.org/repositories/Apache:/MirrorBrain/Debian_8.0/ /" ; \
} >> /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends wget postgresql-client
RUN wget -nv http://download.opensuse.org/repositories/Apache:/MirrorBrain/Debian_8.0/Release.key -O Release.key \
  && apt-key add - < Release.key \
  && apt-get update \
  && apt-get install -y --no-install-recommends mirrorbrain mirrorbrain-tools mirrorbrain-scanner \
                     libapache2-mod-mirrorbrain libapache2-mod-autoindex-mb \
                     apache2-mpm-worker rsync

#Enable Apache modules
RUN { \
  a2enmod form ; \
  a2enmod mirrorbrain ; \
  a2enmod geoip ; \
  a2enmod dbd ; \
  a2enmod autoindex_mb ; \
#  a2enmod asn ; \
}

#Copy files configuration
COPY mirrorbrain.conf /etc/
RUN chmod 0640 /etc/mirrorbrain.conf &&  chown root:mirrorbrain /etc/mirrorbrain.conf
COPY ./public-html/ /usr/local/apache2/htdocs/

COPY start.sh /usr/local/bin 
RUN chmod 0500 /usr/local/bin/start.sh

CMD start.sh

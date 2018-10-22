FROM httpd

#Install needed packages
RUN mkdir -p /usr/share/man/man1/ /usr/share/man/man7/ &&  apt-get update && apt-get install -y --no-install-recommends wget postgresql-client rsync

#Install mirrorbrain from repository
#RUN { \
#  echo "deb http://download.opensuse.org/repositories/Apache:/MirrorBrain/Debian_8.0/ /" ; \
#} >> /etc/apt/sources.list
#
#RUN apt-get update && apt-get install -y --allow-unauthenticated  mirrorbrain mirrorbrain-tools mirrorbrain-scanner libapache2-mod-mirrorbrain libapache2-mod-autoindex-mb 

#Copy files configuration
COPY config/mirrorbrain/mirrorbrain.conf /etc/
RUN chmod 0640 /etc/mirrorbrain.conf &&  chown root:mirrorbrain /etc/mirrorbrain.conf
#COPY ./public-html/ /usr/local/apache2/htdocs/
COPY ./sql/* /usr/share/doc/mirrorbrain/sql/
COPY config/apache/download.kiwix.org /etc/apache2/sites-available/

#Enable Apache modules and site for mirrorbrain
RUN { \
  a2enmod form ; \
  a2enmod mirrorbrain ; \
  a2enmod geoip ; \
  a2enmod dbd ; \
  a2enmod autoindex_mb ; \
# a2enmod asn ; \
#  a2ensite download.kiwix.org ; \ 
}

COPY start.sh /usr/local/bin 
RUN chmod 0500 /usr/local/bin/start.sh

CMD start.sh

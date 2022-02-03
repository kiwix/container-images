FROM debian:buster-slim
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

ENV VERSION_KIWIX_TOOLS 3.2.0-1
ENV LIBRARY_DIR /var/www/library.kiwix.org
ENV VERSION_VARNISH 6.4.0-1~buster_amd64
ENV VARNISH_SECRET notset

# Get rid of the warning: "debconf: unable to initialize frontend: Dialog"
# https://github.com/moby/moby/issues/27988
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Installer necessary packages
RUN apt update 2> /dev/null && \
    apt install -y --no-install-recommends wget cron curl libfindbin-libs-perl \
    libxml-dom-xpath-perl libdatetime-perl liblocales-perl libnumber-bytes-human-perl \
    libxml-simple-perl libgetargs-long-perl libxml2-utils python3 python3-pip \
    python3-setuptools python3-pycountry python3-yaml python3-requests python3-mwclient && \
    wget -o -L --content-disposition https://packagecloud.io/varnishcache/varnish64/packages/debian/buster/varnish_$VERSION_VARNISH.deb/download.deb && \
    apt install -y -f ./varnish_$VERSION_VARNISH.deb && rm varnish_$VERSION_VARNISH.deb && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN wget --no-check-certificate -q -O kiwix-tools.tar.gz http://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS.tar.gz \
  && tar --strip=1 -xzf kiwix-tools.tar.gz -C /usr/local/bin/ kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS/kiwix-serve \
  && tar --strip=1 -xzf kiwix-tools.tar.gz -C /usr/local/bin/ kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS/kiwix-manage \
  && rm -f kiwix-tools.tar.gz

EXPOSE 80

WORKDIR $LIBRARY_DIR

# Copy Perl modules
COPY lib/Mediawiki/Mediawiki.pm /usr/share/perl5/Mediawiki/Mediawiki.pm

# Copy varnish config
COPY varnish/default.vcl /etc/varnish/default.vcl

RUN printf "* - nofile 42000\nroot - nofile 42000" > /etc/security/limits.conf

# Install start script
COPY bin/ /usr/local/bin/
RUN chmod -R 0500 /usr/local/bin/*

ENTRYPOINT ["start.sh"]
CMD ["/usr/sbin/varnishd", "-F", "-a", ":80", "-T", "localhost:6082", "-f", "/etc/varnish/default.vcl", "-S", "/etc/varnish/secret", "-s", "malloc,256m"]

FROM debian:stretch-slim
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

ENV VERSION_KIWIX_TOOLS 3.0.1-8
ENV LIBRARY_DIR /var/www/library.kiwix.org

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget cron libfindbin-libs-perl libxml-dom-xpath-perl libdatetime-perl liblocales-perl libnumber-bytes-human-perl libxml-simple-perl libgetargs-long-perl libxml2-utils python3 python3-pip && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install -U pip setuptools
RUN pip3 install pycountry==18.2.23 PyYAML==3.12 requests==2.18.4
RUN pip3 install mwclient

RUN wget --no-check-certificate -q -O kiwix-tools.tar.gz http://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS.tar.gz \
  && tar --strip=1 -xzf kiwix-tools.tar.gz -C /usr/local/bin/ kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS/kiwix-serve \
  && tar --strip=1 -xzf kiwix-tools.tar.gz -C /usr/local/bin/ kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS/kiwix-manage \
  && rm -f kiwix-tools.tar.gz

EXPOSE 80

WORKDIR $LIBRARY_DIR

#Install start script
COPY bin/ /usr/local/bin/
RUN chmod -R 0500 /usr/local/bin/*

#Copy Perl modules
COPY lib/Mediawiki/Mediawiki.pm /usr/share/perl5/Mediawiki/Mediawiki.pm

CMD start.sh

FROM debian:stretch-slim
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

ENV VERSION_KIWIX_TOOLS 0.7.0

RUN apt-get update && apt-get install -y --no-install-recommends wget

RUN wget --no-check-certificate -q -O kiwix-tools.tar.gz http://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS.tar.gz \
  && tar --strip=1 -xzf kiwix-tools.tar.gz -C /usr/local/bin/ kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS/kiwix-serve \
  && rm -f kiwix-tools.tar.gz
  
EXPOSE 80

WORKDIR /data/library

CMD ["kiwix-serve","--port=80", "--library", "--threads=16", "--verbose", "library.kiwix.org.xml"]

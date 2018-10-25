FROM debian:stretch-slim
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

ENV VERSION_KIWIX_TOOLS 0.6.1-1

RUN apt-get update && apt-get install -y --no-install-recommends wget vim net-tools

RUN wget -q -O - http://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS.tar.gz \
  | tar --strip=1  -xzC /usr/local/bin/ kiwix-tools_linux-x86_64-$VERSION_KIWIX_TOOLS/kiwix-serve
  
WORKDIR /data/library

EXPOSE 4242

CMD ["kiwix-serve","--port=4242", "--library", "--interface=lo", "--threads=16", "--verbose", "library.kiwix.org.xml"]

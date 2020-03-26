FROM ubuntu:bionic

ENV LANG C.UTF-8

RUN apt-get update -y && \
apt-get install --no-install-recommends -y \
# Base build tools
    build-essential automake libtool cmake ccache pkg-config autopoint patch \
    python3-pip python3-setuptools python3-wheel wget unzip \
# Packaged dependencies
    libbz2-dev libmagic-dev uuid-dev zlib1g-dev libicu-dev libpugixml-dev \
    libmicrohttpd-dev aria2 python3-dev \
    liblzma-dev libxapian30 libxapian-dev \
    lzma-dev zlib1g-dev libicu-dev libxapian-dev googletest \
    libcurl4 libcurl4-openssl-dev libunistring-dev \
    libnghttp2-dev libpsl-dev librtmp-dev libssl-dev libkrb5-dev libk5crypto3 libcomerr2 libberkeleydb-perl libldap2-dev \
    && \
  apt-get clean -y && \
  rm -rf /var/lib/apt/lists/* /usr/share/doc/* /var/cache/debconf/*

# ninja, meson, mustache
RUN wget https://github.com/ninja-build/ninja/releases/download/v1.10.0/ninja-linux.zip -O /tmp/ninja-linux.zip && unzip -d /usr/local/bin /tmp/ninja-linux.zip && rm -f /tmp/ninja-linux.zip
RUN pip3 install meson
RUN wget https://raw.githubusercontent.com/kainjow/Mustache/v3.2.1/mustache.hpp -O /usr/include/mustache.hpp

RUN echo "DOWNLOADING libzim..."
RUN wget https://download.openzim.org/release/libzim/libzim_linux-x86_64-6.0.2.tar.gz -O /tmp/libzim_linux-x86_64-6.0.2.tar.gz && tar -C /usr --strip-components=1 -xf /tmp/libzim_linux-x86_64-6.0.2.tar.gz && rm -f /tmp/libzim_linux-x86_64-6.0.2.tar.gz
RUN ln -s /usr/lib/x86_64-linux-gnu/libzim.so.6 /usr/lib/x86_64-linux-gnu/libzim.so
RUN printf "prefix=/usr\nlibdir=\${prefix}/lib/x86_64-linux-gnu\nincludedir=\${prefix}/include\n\nName: libzim\nDescription: A Library to zim.\nVersion: 6.0.2\nRequires: liblzma, zlib, xapian-core, icu-i18n\nLibs: -L\${libdir} -lzim -pthread\nCflags: -I\${includedir} -pthread\n" > /usr/lib/x86_64-linux-gnu/pkgconfig/libzim.pc

RUN echo "COMPILING kiwix-lib"
RUN wget https://github.com/rgaudin/kiwix-lib/archive/master.zip -O /tmp/master.zip && unzip -d /tmp /tmp/master.zip && mv /tmp/kiwix-lib-master/ /kiwix-lib && rm -f /tmp/master.zip
RUN cd /kiwix-lib && meson --prefix=/usr . build && ninja -C build && ninja -C build install && rm -rf /kiwix-lib
        
RUN echo "COMPILING kiwix-tools"
RUN wget https://github.com/rgaudin/kiwix-tools/archive/master.zip -O /tmp/master.zip && unzip -d /tmp /tmp/master.zip && mv /tmp/kiwix-tools-master/ /kiwix-tools && rm -f /tmp/master.zip
RUN cd /kiwix-tools && meson --prefix=/usr . build && ninja -C build && ninja -C build install && rm -rf /kiwix-tools
    
EXPOSE 80
RUN printf '#!/bin/sh\nCMD="kiwix-serve --port=80 $@"\necho $CMD\n$CMD' > /usr/local/bin/entrypoint && chmod +x /usr/local/bin/entrypoint
ENTRYPOINT ["entrypoint"]

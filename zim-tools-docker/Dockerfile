FROM debian:stretch-slim  
MAINTAINER kiwix

RUN mkdir -p /root/.local/bin
ENV PATH="/root/.local/bin:${PATH}"
WORKDIR /root/.local

RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget unzip xz-utils \
    g++ pkg-config cmake python3.5 python3-pip cython3 ccache \
    zlib1g-dev liblzma-dev libicu-dev libbz2-dev libxapian-dev && \
    rm -r /var/lib/apt/lists/*

RUN wget -q https://bootstrap.pypa.io/get-pip.py && \
  python3 get-pip.py --user && \
  python3 -m pip install --user --upgrade pip && \
  python3 -m pip install --user meson && \
  rm get-pip.py

RUN wget -q https://github.com/ninja-build/ninja/releases/download/v1.8.2/ninja-linux.zip && \
  unzip ninja-linux.zip ninja && \
  cp ninja bin/ && \
  rm ninja-linux.zip

RUN git clone -q --depth=1 https://github.com/openzim/libzim && \
  cd libzim && \
  wget -q  http://tmp.kiwix.org/ci/deps_linux_i586_dyn_libzim.tar.xz && \
  tar -xJf deps_linux_i586_dyn_libzim.tar.xz && \
  rm deps_linux_i586_dyn_libzim.tar.xz && \
  export PKG_CONFIG_PATH=BUILD_i586_dyn/INSTALL/lib/x86_64-linux-gnu/pkgconfig && \
  meson . build && ninja -C build && ninja -C build install && cd .. && \
  rm -rf libzim

RUN git clone -q --depth=1 https://github.com/openzim/zim-tools && \
  cd zim-tools && \
  wget -q http://tmp.kiwix.org/ci/deps_linux_i586_dyn_zim-tools.tar.xz && \
  tar -xJf deps_linux_i586_dyn_zim-tools.tar.xz && rm deps_linux_i586_dyn_zim-tools.tar.xz && \
  export PKG_CONFIG_PATH=BUILD_i586_dyn/INSTALL/lib/x86_64-linux-gnu/pkgconfig && \
  meson . build && ninja -C build && ninja -C build install && cd .. && \
  rm -rf zim-tools
  
ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"
  
CMD bash

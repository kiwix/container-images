FROM ubuntu:oracular
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

ENV LANG=C.UTF-8
ENV OS_NAME=oracular
ENV DEBIAN_FRONTEND=noninteractive
# QT_SELECT=qt6 with qtchooser allows building with 'qmake' instead of 'qmake6'
ENV QT_SELECT=qt6

RUN apt update -q \
  && apt install -q -y --no-install-recommends \
# Base build tools
    build-essential automake libtool cmake ccache pkg-config autopoint patch \
    python3-full python3-pip python3-setuptools python3-wheel git subversion \
    wget unzip ninja-build openssh-client curl libgl-dev \
# Packaged dependencies
    libbz2-dev libmagic-dev uuid-dev zlib1g-dev \
    libmicrohttpd-dev aria2 libgtest-dev libgl-dev \
# Devel package to compile python modules
    libxml2-dev libxslt-dev python3-dev \
# Qt packages
    qt6-base-dev qt6-base-dev-tools qt6-webengine-dev libqt6webenginecore6-bin libqt6svg6 qtchooser \
# To create the appimage of kiwix-desktop
    libfuse3-3 fuse3 patchelf \
# Flatpak tools
    elfutils flatpak flatpak-builder \
# Cross win32 compiler
    g++-mingw-w64-i686 gcc-mingw-w64-i686 gcc-mingw-w64-base mingw-w64-tools \
# Cross compile i586
    libc6-dev-i386 lib32stdc++6 gcc-multilib g++-multilib \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* /usr/share/doc/* /var/cache/debconf/* \
  && pip3 install meson==1.6.1 pytest gcovr requests distro --break-system-packages \
  && qtchooser -install qt6 $(which qmake6)

# Create user
RUN groupadd --gid 121 runner
RUN useradd --uid 1001 --gid 121 --create-home runner
USER runner
ENV PATH=/home/runner/.local/bin:$PATH

FROM ubuntu:jammy
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

ENV LANG C.UTF-8
ENV OS_NAME jammy
ENV DEBIAN_FRONTEND noninteractive

RUN apt update -q \
  && apt install -q -y --no-install-recommends \
# Base build tools
    build-essential automake libtool cmake ccache pkg-config autopoint patch \
    python3-pip python3-setuptools python3-wheel git subversion wget unzip \
    ninja-build openssh-client curl libgl-dev \
# Packaged dependencies
    libbz2-dev libmagic-dev uuid-dev zlib1g-dev \
    libmicrohttpd-dev aria2 libgtest-dev libgl-dev \
# Devel package to compile python modules
    libxml2-dev libxslt-dev python3-dev \
# Needed by Qt 6.8.3 installed via aqtinstall
    libfreetype6 libfontconfig1 libegl1 libnss3 libthai0 \
    libxkbcommon0 libxkbcommon-x11-0 libxkbfile1 \
    libasound2 libxrandr2 libxdamage1 libxcomposite1 \
    libxtst6 libxi6 libwayland-dev libcups2 \
    libxcb-icccm4 libxcb-shape0 libxcb-keysyms1 libxcb-xkb1 libxcb-cursor0 \
# Temporary (until libtorrent is made a dependency in kiwix-build)
    libtorrent-rasterbar-dev \
# To create the appimage of kiwix-desktop
    libfuse2 fuse patchelf \
# Flatpak tools
    elfutils flatpak flatpak-builder \
# Cross win32 compiler
    g++-mingw-w64-i686 gcc-mingw-w64-i686 gcc-mingw-w64-base mingw-w64-tools \
# Cross compile i586
    libc6-dev-i386 lib32stdc++6 gcc-multilib g++-multilib \
# Other tools (to remove)
#    vim less grep \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* /usr/share/doc/* /var/cache/debconf/* \
  && pip3 install meson==1.6.1 pytest gcovr requests distro

# Create user
RUN groupadd --gid 121 runner
RUN useradd --uid 1001 --gid 121 --create-home runner
USER runner
ENV PATH /home/runner/.local/bin:$PATH

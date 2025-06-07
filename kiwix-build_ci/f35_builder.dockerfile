FROM fedora:35
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

ENV LANG C.UTF-8
ENV OS_NAME f35

RUN dnf install -y --nodocs \
# Base build tools
    make automake libtool cmake git-core subversion pkg-config gcc-c++ \
    wget unzip ninja-build ccache which patch gcovr xz openssh-clients \
    python3-pip \
# Cross win32 compiler
    mingw32-gcc-c++ mingw32-bzip2-static mingw32-win-iconv-static \
    mingw32-winpthreads-static mingw32-zlib-static mingw32-xz-libs-static \
    mingw32-libmicrohttpd \
# python3
    python3-pip python-unversioned-command \
# Other tools (to remove)
#    vim less grep
  && dnf remove -y "*-doc" \
  && dnf autoremove -y \
  && dnf clean all \
  && pip3 install meson==1.6.1 pytest requests distro

# Create user
RUN groupadd --gid 121 runner
RUN useradd --uid 1001 --gid 121 --create-home runner
USER runner
ENV PATH /home/runner/.local/bin:$PATH

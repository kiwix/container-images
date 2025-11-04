FROM quay.io/pypa/manylinux_2_28_x86_64:2025.11.02-1
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

ENV LANG C.UTF-8
ENV OS_NAME manylinux

RUN dnf install -y --nodocs \
# Base build tools
    make automake libtool cmake git-core subversion pkg-config gcc-c++ \
    wget unzip ninja-build which patch xz openssh-clients \
# Other tools (to remove)
    vim less grep \
  && dnf remove -y "*-doc" \
  && dnf autoremove -y \
  && dnf clean all \
  && python3.12 -m pip install meson==1.6.1 pytest requests distro

ENV PATH /opt/_internal/cpython-3.12.7/bin:$PATH

# Create user
RUN groupadd --gid 121 runner
RUN useradd --uid 1001 --gid 121 --create-home runner
USER runner
WORKDIR /home/runner

RUN mkdir -p /home/runner/.local/bin
RUN ln -s /usr/local/bin/python3.12 /home/runner/.local/bin/python
ENV PATH /home/runner/.local/bin:$PATH

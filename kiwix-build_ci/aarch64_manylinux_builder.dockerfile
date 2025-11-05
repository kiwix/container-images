FROM quay.io/pypa/manylinux_2_28_aarch64:2025.11.02-1
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

ENV LANG C.UTF-8
ENV OS_NAME aarch64_manylinux

RUN dnf install -y --nodocs \
# Base build tools
    make automake libtool cmake git-core subversion pkg-config gcc-c++ \
    wget unzip ninja-build which patch xz openssh-clients \
# Other tools (to remove)
    vim less grep \
  && dnf remove -y "*-doc" \
  && dnf autoremove -y \
  && dnf clean all \
  && /usr/bin/env python3 -m ensurepip \
  && /usr/bin/env python3 -m pip install meson==1.6.1 pytest requests distro

# Create user
RUN groupadd --gid 121 runner
RUN useradd --uid 1001 --gid 121 --create-home runner
USER runner
WORKDIR /home/runner

RUN mkdir -p /home/runner/.local/bin
RUN ln -s $(which python3) /home/runner/.local/bin/python
ENV PATH /home/runner/.local/bin:$PATH
RUN printf '#!/bin/bash\n/usr/bin/env python3 -m pip $@\n' > /home/runner/.local/bin/pip3 \
  && chmod +x /home/runner/.local/bin/pip3

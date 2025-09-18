FROM alpine:3.16
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

ENV LANG C.UTF-8
ENV OS_NAME alpine

RUN apk update -q \
  && apk add -q --no-cache \
# Base build tools
        bash build-base git py3-pip \
        automake autoconf cmake gettext-dev libtool openssl-dev \
# Packaged dependencies
        xz-dev \
        zstd-dev \
        xapian-core-dev \
        icu-dev icu-data-full

# Create user
RUN addgroup --gid 121 runner
RUN adduser -u 1001 -G runner -h /home/runner -D runner
USER runner
ENV PATH /home/runner/.local/bin:$PATH
RUN pip3 install meson==1.6.1 ninja wheel pytest gcovr requests distro ; \
    ln -s /usr/bin/python3 /home/runner/.local/bin/python

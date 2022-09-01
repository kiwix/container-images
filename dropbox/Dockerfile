FROM debian:11-slim
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

# system dependencies
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
    wget build-essential make ca-certificates python python3 \
    openssh-sftp-server openssh-server  \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && wget --progress=dot:giga https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 \
    && mv dumb-init_1.2.5_x86_64 /usr/bin/dumb-init \
    && chmod +x /usr/bin/dumb-init

# build and configure rssh
# we are keeping source here as it's small and hosted on sourceforge
WORKDIR /usr/src/
RUN wget --progress=dot:giga https://mirror.download.kiwix.org/dev/rssh-2.3.4.tar.gz && \
    tar -xvf rssh-2.3.4.tar.gz
WORKDIR /usr/src/rssh-2.3.4
RUN ./configure --prefix=/ && make && make install && \
    printf "allowscp\nallowsftp\n" > /etc/rssh.conf

WORKDIR /
# setup a chroot jail at /jail, patching ini file
RUN wget --progress=dot:giga https://olivier.sessink.nl/jailkit/jailkit-2.21.tar.gz && \
    tar xf jailkit-2.21.tar.gz && \
    cd jailkit-2.21 && \
    ./configure && \
    make && make install && \
    rm -rf /jailkit-2.21 && \
    rm -f /jailkit-2.21.tar.gz && \sed -i.bak -e '116d' /etc/jailkit/jk_init.ini && \
    printf "\n[rssh]\npaths = /bin/rssh, /etc/rssh.conf\n" >> /etc/jailkit/jk_init.ini && \
    mkdir -p /jails && \chown root:root /jails

COPY motd /etc/motd
COPY sshd_config /etc/ssh/sshd_config
COPY create-user.py /usr/local/bin/create-user
COPY entrypoint.py /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/create-user /usr/local/bin/entrypoint && mkdir -p /etc/ssh/authorized-keys/

ENTRYPOINT ["/usr/bin/dumb-init", "--", "entrypoint"]
CMD ["/usr/sbin/sshd", "-D"]

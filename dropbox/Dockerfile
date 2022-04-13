FROM debian:11-slim
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

# system dependencies
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
    wget build-essential make ca-certificates python \
    openssh-sftp-server openssh-server  \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
    rm -f jailkit-2.21.tar.gz && \sed -i.bak -e '116d' /etc/jailkit/jk_init.ini && \
    printf "\n[rssh]\npaths = /bin/rssh, /etc/rssh.conf\n" >> /etc/jailkit/jk_init.ini && \
    mkdir -p /jail && \chown root:root /jail

COPY motd /etc/motd

# create and prepare user, fixing shell
RUN groupadd -g 1000 -r ci && \
    jk_init -v -j /jail rssh ssh scp sftp && \
    useradd -g ci -u 1000 -M -N -r -s /bin/rssh ci && \
    jk_jailuser -m -j /jail -s /bin/rssh ci && \
    sed -i 's/usr\/sbin\/jk_chrootsh/bin\/rssh/' /etc/passwd && \
    mkdir -p /jail/data

# OpenSSH server
COPY sshd_config /etc/ssh/sshd_config
# add public key placeholder
RUN mkdir -p /etc/ssh/authorized-keys/

# mount target dir anywhere under /jail (except for existing tree: bin dev etc lib lib64 usr)
# each volume you want to allow uploads to must be owned by ci:ci (1000:1000)
# with a write-appropriate mode
VOLUME /jail/data

# additional sshd options
env SSHD_OPTS ""
env PUBKEYS ""

RUN printf "#!/bin/sh\n\
set -e \n\
if [ ! -d /run/sshd ]; then\n\
  mkdir /run/sshd\n\
  chmod 0755 /run/sshd\n\
fi\n\
printf \"\$PUBKEYS\" >> /etc/ssh/authorized-keys/ci\n\
nbkeys=\$(wc -l < /etc/ssh/authorized-keys/ci)\n\
echo \"User “ci” has \${nbkeys} public keys allowed\"\n\
echo \"Starting OpenBSD Secure Shell server...\"\n\
/usr/sbin/sshd -D $SSHD_OPTS\n\
" > /usr/local/bin/start-opensshd && chmod +x /usr/local/bin/start-opensshd

CMD ["start-opensshd"]

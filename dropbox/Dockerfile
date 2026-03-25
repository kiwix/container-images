FROM debian:13-slim AS builder
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

# system dependencies
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        wget ca-certificates build-essential make openssh-sftp-server openssh-server

# build and configure rssh
# we are keeping source here as it's small and hosted on sourceforge
WORKDIR /usr/src/
RUN wget --progress=dot:giga https://dev.kiwix.org/rssh-2.3.4.tar.gz && \
    tar -xvf rssh-2.3.4.tar.gz
WORKDIR /usr/src/rssh-2.3.4
RUN ./configure --prefix=/ && make && make install && \
    printf "allowscp\nallowsftp\n" > /etc/rssh.conf

FROM debian:13-slim

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates openssh-sftp-server openssh-server \
        python3 fail2ban dumb-init jailkit \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p -- "/libexec"

COPY --from=builder /bin/rssh /bin/rssh
COPY --from=builder /libexec/rssh_chroot_helper /libexec/rssh_chroot_helper

WORKDIR /
# setup a chroot jail at /jail, patching ini file
RUN printf "\n[rssh]\npaths = /bin/rssh, /etc/rssh.conf\n" >> /etc/jailkit/jk_init.ini \
    && printf "allowscp\nallowsftp\n" > /etc/rssh.conf \
    && mkdir -p /jails \
    && chown root:root /jails

COPY motd /etc/motd
COPY sshd_config /etc/ssh/sshd_config
COPY create-user.py /usr/local/bin/create-user
COPY entrypoint.py /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/create-user /usr/local/bin/entrypoint && mkdir -p /etc/ssh/authorized-keys/

ENTRYPOINT ["/usr/bin/dumb-init", "--", "entrypoint"]
CMD ["/usr/sbin/sshd", "-D"]

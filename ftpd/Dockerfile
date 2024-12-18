FROM alpine:3.21
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

RUN \
    apk add --no-cache \
        dumb-init \
        pure-ftpd \
    # must exists as it is root of data (should be mounted usually)
    && mkdir -p /var/lib/ftp \
    && printf "\
MaxClientsNumber             25\n\
Daemonize                    no\n\
VerboseLog                   yes\n\
AnonymousOnly                yes\n\
AllowAnonymousFXP            yes\n\
AnonymousCantUpload          yes\n\
" >> /etc/pure-ftpd.conf

VOLUME /var/lib/ftp
EXPOSE 21

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/sbin/pure-ftpd"]

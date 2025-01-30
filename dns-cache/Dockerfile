FROM alpine:3.13
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

ENV SHELL=bash

RUN set -e \
    && apk update \
    && apk --no-cache add dumb-init bash curl \
    # to setup a DNS cache
    && curl -L -o dnsproxy.tar.gz https://github.com/AdguardTeam/dnsproxy/releases/download/v0.74.1/dnsproxy-linux-amd64-v0.74.1.tar.gz \
    && tar x -f dnsproxy.tar.gz --strip-components 2 \
    && mv dnsproxy /usr/bin/

EXPOSE 53

RUN printf "#!/bin/sh\n\
echo "---"\n\
cat /usr/local/bin/entrypoint\n\
echo "---"\n\
echo 'nameserver 127.0.0.1' > /etc/resolv.conf\n\
exec \"\$@\"\n\
" > /usr/local/bin/entrypoint \
&& chmod +x /usr/local/bin/entrypoint

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/entrypoint"]
CMD ["dnsproxy", "--cache", "--cache-min-ttl", "3600", "--cache-size", "1024", "--hosts-file-enabled", "--ipv6-disabled", "--listen", "0.0.0.0", "--port", "53", "--upstream", "https://1.1.1.1/dns-query"]

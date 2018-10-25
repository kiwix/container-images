FROM debian:stretch-slim  
MAINTAINER kiwix

RUN apt-get update && apt-get install -y --no-install-recommends rsync

EXPOSE 873

COPY rsyncd.* /etc/
CMD rsync --daemon --no-detach --log-file /dev/stdout

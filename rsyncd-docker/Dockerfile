FROM debian:buster-slim
MAINTAINER kiwix

RUN apt-get update && apt-get install -y --no-install-recommends rsync

EXPOSE 873

COPY rsyncd.* /etc/
CMD nice -n -10 ionice -c2 -n2 rsync --daemon --no-detach --log-file /dev/stdout

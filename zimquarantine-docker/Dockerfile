FROM debian:stretch-slim  
MAINTAINER kiwix

ENV ZIM_TOOL_VERSION=1.0.1
ENV ZIM_SRC_DIR=/zim_to_validate
ENV ZIM_DST_DIR=/zim

#install needed packages
RUN apt-get update && apt-get install -y --no-install-recommends wget cron && rm -r /var/lib/apt/lists/*

#install zim-tools
RUN wget -q http://download.openzim.org/release/zim-tools/zim-tools_linux-x86_64-$ZIM_TOOL_VERSION.tar.gz && \
  tar -xzf zim-tools_linux-x86_64-$ZIM_TOOL_VERSION.tar.gz && \
  cp zim-tools_linux-x86_64-$ZIM_TOOL_VERSION/* /usr/local/bin/ && \
  rm -rf zim-tools_linux-x86_64-$ZIM_TOOL_VERSION*

#install zim validation
COPY zimValidation.sh /usr/local/bin/
RUN chmod 0500 /usr/local/bin/zimValidation.sh

#add validation in cron
RUN { \
    echo "#!/bin/sh" ; \
    echo "/usr/bin/flock -w 0 /dev/shm/cron.lock find $ZIM_SRC_DIR -iname "*.zim" -exec zimValidation.sh  "{}" $ZIM_SRC_DIR $ZIM_DST_DIR ';' >> /dev/shm/zimvalidation.log 2>&1" ; \
  } > /etc/cron.hourly/zimvalidation && chmod 0500 /etc/cron.hourly/zimvalidation

CMD cron -f

FROM debian:stretch-slim  
MAINTAINER kiwix

ENV ZIM_TOOLS_URL http://download.openzim.org/release/zim-tools/zim-tools_linux-x86_64-1.0.4.tar.gz
ENV ZIM_SRC_DIR /zim_to_check
ENV ZIM_DST_DIR /zim
ENV ZIM_QUAR_DIR /zim_quarantine
ENV ZIMCHECK_OPTION -A
ENV VALIDATION_LOG_DIR /zim_log

#install needed packages
RUN apt-get update && apt-get install -y --no-install-recommends wget cron && rm -r /var/lib/apt/lists/*

#install zim-tools
RUN wget -O zim-tools.tar.gz -q $ZIM_TOOLS_URL && \
  tar -xzf zim-tools.tar.gz && \
  cp zim-tools*/* /usr/local/bin/ && \
  rm -rf zim-tools*

#install zim validation
COPY zimValidation.sh /usr/local/bin/
RUN chmod 0500 /usr/local/bin/zimValidation.sh

#run validation every minute
CMD echo "* *  * * *  root  /usr/bin/flock -w 0 /dev/shm/cron.lock find $ZIM_SRC_DIR -iname \"*.zim\" -exec bash /usr/local/bin/zimValidation.sh  \"{}\" $ZIM_SRC_DIR $ZIM_DST_DIR $ZIM_QUAR_DIR $VALIDATION_LOG_DIR \"$ZIMCHECK_OPTION\" $VALIDATION_OPTION ';' >> /dev/shm/zimvalidation.log 2>&1" >> /etc/cron.d/zimvalidation && cron -f


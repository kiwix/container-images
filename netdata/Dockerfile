FROM netdata/netdata:latest
LABEL org.opencontainers.image.source https://github.com/kiwix/container-images

ENV DO_NOT_TRACK 1
ENV NETDATA_HOSTNAME monitoring.openzim.org
ENV STREAM_KEY 7DC0DDB8-8EAA-4391-AF5D-BE017EECF0EE

COPY netdata.conf /etc/netdata/netdata.conf

# disable all external modules
RUN printf "enabled: no\n" | tee /etc/netdata/python.d.conf /etc/netdata/go.d.conf /etc/netdata/node.d.conf

# add clean-up script
RUN printf "#!/bin/bash\nrm -rf /var/cache/netdata/* && kill 1\n" \
> /usr/local/bin/reset-netdata \
&& chmod a+x /usr/local/bin/reset-netdata

COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod a+x /usr/local/bin/entrypoint

ENTRYPOINT ["entrypoint"]

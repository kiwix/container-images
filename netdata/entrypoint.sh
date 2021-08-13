#!/bin/bash

# update stream allow from list using workers list on github
WORKERS_URL=https://raw.githubusercontent.com/openzim/zimfarm/master/workers/contrib/workers.json
IPS=$(echo -n $(curl -sS "${WORKERS_URL}" | jq --raw-output ".[]"))

# write stream config
read -d '' STREAM_CONF << EOF
[${STREAM_KEY}]
 enabled = yes
 default history = 86400
 default memory = dbengine
 health enabled by default = auto
 multiple connections = allow
 allow from = ${IPS}
EOF
echo "${STREAM_CONF}" > /etc/netdata/stream.conf


# setup custom hostname for node in netdata
if [ ! -z "${NETDATA_HOSTNAME}" ]
then
    printf "\n hostname = ${NETDATA_HOSTNAME}\n" >> /etc/netdata/netdata.conf
fi

# netdata's entrypoint
/usr/sbin/run.sh

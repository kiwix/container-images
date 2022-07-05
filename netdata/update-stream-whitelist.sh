#!/bin/sh

echo "RUNNING UPDATE STREAM"

echo $(date) >> /tmp/top

WORKERS_IPS_FILE=/tmp/workers_ips
touch $WORKERS_IPS_FILE

WORKERS_IPS=$(echo -n $(curl -sS https://api.farm.openzim.org/v1/workers/ | jq --raw-output '.items[].last_ip'))
if [ "$WORKERS_IPS" = "$(cat $WORKERS_IPS_FILE)" ] ; then
    echo "already OK"
    # exit 0
fi

echo -n $WORKERS_IPS > $WORKERS_IPS_FILE

# update stream allow from list using workers list on github
IPS="${STREAM_WHITELIST} ${WORKERS_IPS}"

echo "IPS:: $IPS"

# write stream config
read -d '' STREAM_CONF << EOF
[${STREAM_KEY}]
 enabled = yes
 default history = 86400
 default memory = dbengine
 health enabled by default = auto
 timeout seconds = 60
 buffer size bytes = 1048576
 reconnect delay seconds = 5
 initial clock resync iterations = 60
 multiple connections = allow
 allow from = ${IPS}
EOF
echo "${STREAM_CONF}" > /etc/netdata/stream.conf

killall netdata || true
sleep 5
/usr/sbin/netdata -u "${DOCKER_USR}" -D -s /host -p "${NETDATA_LISTENER_PORT}" &

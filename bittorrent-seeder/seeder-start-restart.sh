#!/bin/bash

# Start-restart script for Kiwix-seeder
#
# Assumes an optional (yet recommended) config file in /etc/seeder.config
# to overwrite the following variables.

CONTAINER_NAME="seeder"                             # name of docker container
IMAGE="ghcr.io/kiwix/bittorrent-seeder:latest"      # docker image to use

DATA_PATH=$(pwd)/kiwix-seeder                       # path to store ZIM files (and incomplete .!qB ones) in (there's no hierarchy)
MAX_STORAGE="10GiB"                                 # maximum disk-space to use
SLEEP_INTERVAL="5m"                                 # how long to pause in-between catalog checks when using --loop
DEBUG=""                                            # whether to print debug logs (set to 1 to enable)

# the following applies to those using the in-container qBittorrent
# If using a remote qBittorrent instance, see NO_DEAMON below
QBT_TORRENTING_PORT=6901                            # port to use for bittorrent. **MUST** be manually opened and forwarded to this host's IP as uPNP would not work accross docker
QBT_PASSWORD=""                                     # qBittorrent WebUI password. If empty, one will be gen and printed
WEBUI_PORT=8000                                     # port on this host to map to the qBittorrent WebUI (so you can monitor it)
# qBittorrent connection settings (defaults copied from qBittorrent)
QBT_MAX_CONNECTIONS=500
QBT_MAX_CONNECTIONS_PER_TORRENT=100
QBT_MAX_UPLOADS=20
QBT_MAX_UPLOADS_PER_TORRENT=5
# END OF CONFIG

if [ -f /etc/seeder.config ]; then
    source /etc/seeder.config
fi

# already running?
docker ps |grep $CONTAINER_NAME |awk '{print $1}' | while read line ; do
    echo ">stopping seeder container $line"
    docker stop $line
    echo ">removing seeder container $line"
    docker rm $line
done

docker stop $CONTAINER_NAME
docker rm --force $CONTAINER_NAME

echo ">pulling image $IMAGE…"
docker pull $IMAGE

echo ">starting seeder container"
docker run \
    --name $CONTAINER_NAME \
    -v $DATA_PATH:/data \
    -p $QBT_TORRENTING_PORT:$QBT_TORRENTING_PORT \
    -p $QBT_TORRENTING_PORT:$QBT_TORRENTING_PORT/udp \
    -p $WEBUI_PORT:80 \
    -e DEBUG=$DEBUG \
    -e QBT_PASSWORD="$QBT_PASSWORD" \
    -e QBT_TORRENTING_PORT=$QBT_TORRENTING_PORT \
    -e QBT_MAX_CONNECTIONS=$QBT_MAX_CONNECTIONS \
    -e QBT_MAX_CONNECTIONS_PER_TORRENT=$QBT_MAX_CONNECTIONS_PER_TORRENT \
    -e QBT_MAX_UPLOADS=$QBT_MAX_UPLOADS \
    -e QBT_MAX_UPLOADS_PER_TORRENT=$QBT_MAX_UPLOADS_PER_TORRENT \
    -e MAX_STORAGE=$MAX_STORAGE \
    -e SLEEP_INTERVAL=$SLEEP_INTERVAL \
    --restart unless-stopped \
    --detach \
    $IMAGE \
    kiwix-seeder --loop --all-good


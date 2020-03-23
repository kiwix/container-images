#!/bin/bash

kalite-setup.sh || exit 1

# launch nginx in the background
if [ ! -z $USE_NGINX ]; then
    echo "starting nginx (USE_NGINX=${USE_NGINX})"
    nginx &
fi

# launch ka-lite (or command)
echo "starting container command (kalite?)"
exec "$@"

#!/bin/bash

NAME=borgbase_test
COMMENT=backup@${NAME}
DIR=`pwd`/.ssh
PRIV_KEY_FILE=${DIR}/${NAME}_id
KNOWN_HOSTS_FILE=${DIR}/known_hosts
CONFIG_FILE=${DIR}/config

mkdir -p .ssh
rm ${PRIV_KEY_FILE}* ${KNOWN_HOSTS_FILE} ${CONFIG_FILE}
ssh-keygen -t ed25519 -a 100 -P '' -C ${COMMENT} -f ${PRIV_KEY_FILE}

echo -e \
"Host *.borgbase.com\n" \
"  IdentityFile ${PRIV_KEY_FILE}\n" \
"  UserKnownHostsFile ${KNOWN_HOSTS_FILE}" \
> ${CONFIG_FILE}

#!/bin/bash
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#

SSH_DIR=`pwd`/.ssh
SSH_PRIV_KEY_FILE=${SSH_DIR}/${BACKUP_ID}_id
SSH_PUB_KEY_FILE=${SSH_PRIV_KEY_FILE}.pub

function create_ssh_config_file {
    KNOWN_HOSTS_FILE=${SSH_DIR}/known_hosts
    CONFIG_FILE=${SSH_DIR}/config

    echo -e \
    "Host *.borgbase.com\n" \
    "  IdentityFile ${SSH_PRIV_KEY_FILE}\n" \
    "  UserKnownHostsFile ${KNOWN_HOSTS_FILE}" \
    > ${CONFIG_FILE}
}

mkdir -p .ssh

export BW_SESSION=`bw login --raw ${BW_EMAIL} ${BW_PASSWORD}`

if bw get password ${BACKUP_ID} > ${SSH_PUB_KEY_FILE}
then
    echo "SSH key retrieval success"
    SSH_PUB_KEY=`cat ${SSH_PUB_KEY_FILE}`
else
    COMMENT=backup@${BACKUP_ID}
    
    echo "Generate SSH key ..."
    rm ${SSH_PRIV_KEY_FILE}* ${KNOWN_HOSTS_FILE} ${CONFIG_FILE}
    ssh-keygen -t ed25519 -a 100 -P '' -C ${COMMENT} -f ${SSH_PRIV_KEY_FILE}
    
    echo "Save key to BitWarden"
    SSH_PUB_KEY=`cat ${SSH_PUB_KEY_FILE}`
    SSH_PRIV_KEY=`cat ${SSH_PRIV_KEY_FILE}`
    LOGIN_ENTRY='{"password":"'"${SSH_PUB_KEY}"'","totp":"'"${SSH_PRIV_KEY}"'"}'
    bw get template item | jq '.name = "'${BACKUP_ID}'"' | jq ".login = ${LOGIN_ENTRY}" | bw encode | bw create item
fi

create_ssh_config_file

#$BACKUP_DIR

/bin/bash

bw logout

#!/bin/bash
#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
# ENV :
# - BORGBASE_NAME : name of backup
# - BORGBASE_KEY : Borgbase API key
# - BW_EMAIL : BitWarden account email used to save key pair
# - BW_PASSWORD : BitWarden master password

SSH_DIR=`pwd`/.ssh
SSH_PRIV_KEY_FILE=${SSH_DIR}/${BORGBASE_NAME}_id
SSH_PUB_KEY_FILE=${SSH_PRIV_KEY_FILE}.pub
SSH_TYPE_KEY=ed25519
SSH_KDF=100

function create_ssh_config_file {
    export KNOWN_HOSTS_FILE=${SSH_DIR}/known_hosts
    CONFIG_FILE=${SSH_DIR}/config

    echo -e \
    "Host *.borgbase.com\n" \
    "  IdentityFile ${SSH_PRIV_KEY_FILE}\n" \
    "  UserKnownHostsFile ${KNOWN_HOSTS_FILE}" \
    > ${CONFIG_FILE}
}

function generate_ssh_key {
    COMMENT=backup@${BORGBASE_NAME}
    rm ${SSH_PRIV_KEY_FILE}* ${KNOWN_HOSTS_FILE} ${CONFIG_FILE}
    ssh-keygen -t ${SSH_TYPE_KEY} -a ${SSH_KDF} -N '' -C ${COMMENT} -f ${SSH_PRIV_KEY_FILE}
}

function save_key {
    SSH_PUB_KEY=`cat ${SSH_PUB_KEY_FILE}`
    SSH_PRIV_KEY=`cat ${SSH_PRIV_KEY_FILE}`
    LOGIN_ENTRY='{"username":"'"${SSH_PUB_KEY}"'","password":"'"${SSH_PRIV_KEY}"'"}'
    bw get template item | jq '.name = "'${BORGBASE_NAME}'"' | jq ".login = ${LOGIN_ENTRY}" | bw encode | bw create item
}

function init_ssh_config {
    export BW_SESSION=`bw login --raw ${BW_EMAIL} ${BW_PASSWORD}`

    if bw get username ${BORGBASE_NAME} > ${SSH_PUB_KEY_FILE}
    then
        echo "SSH key retrieval success"
        echo >> ${SSH_PUB_KEY_FILE}
        bw get password ${BORGBASE_NAME} > ${SSH_PRIV_KEY_FILE}
        echo >> ${SSH_PRIV_KEY_FILE}
        chmod 600 ${SSH_PRIV_KEY_FILE}
    else
        echo "Generate SSH key ..."
        generate_ssh_key
        
        echo "Save key to BitWarden"
        save_key
    fi

    create_ssh_config_file

    bw logout
}

init_ssh_config

init_borgbase_repository.py

.local/bin/borgmatic -c/root/.config/borgmatic/config.yaml  --verbosity 1 --files

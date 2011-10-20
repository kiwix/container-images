#!/bin/bash

IPT=/sbin/iptables
# Max connection in seconds
SECONDS=100
# Max connections per IP
BLOCKCOUNT=20
# ....
# ..

# default action can be DROP or REJECT
DACTION="DROP"
$IPT -I INPUT -p tcp --dport 80 -i eth0 -m state --state NEW -m recent --set
$IPT -I INPUT -p tcp --dport 80 -i eth0 -m state --state NEW -m recent --update --seconds ${SECONDS} --hitcount ${BLOCKCOUNT} -j ${DACTION}

# exception for mozilla
$IPT -I INPUT -s 63.245.208.135 -j ACCEPT

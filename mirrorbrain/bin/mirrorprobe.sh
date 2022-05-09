#!/bin/bash

for SITE in `/usr/local/bin/mb list | grep -v mirror.tn`
do
    echo "Mirrorprobe $SITE"
    /usr/bin/mirrorprobe $SITE
done

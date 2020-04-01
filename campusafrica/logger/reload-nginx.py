#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ai ts=4 sts=4 et sw=4 nu

""" request foreign container's nginx to re-open its log file

    docker exec -it reverse-proxy bash -c 'kill -USR1 $(cat /var/run/nginx.pid)' """

from __future__ import unicode_literals, absolute_import, division, print_function

import docker

env = {
    l.split("=", 1)[0].strip(): l.split("=", 1)[1].strip()
    for l in open("/etc/default/logger").readlines()
    if l.strip()
}

client = docker.from_env()
client.api.exec_start(
    client.api.exec_create(
        env["NGINX_CONTAINER"], "bash -c 'kill -USR1 $(cat /var/run/nginx.pid)'"
    )["Id"]
)

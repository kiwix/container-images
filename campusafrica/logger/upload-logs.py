#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ai ts=4 sts=4 et sw=4 nu

from __future__ import unicode_literals, absolute_import, division, print_function

""" run periodicaly to upload and process rotated logs """

import os
import re
import subprocess

env = {
    l.split("=", 1)[0].strip(): l.split("=", 1)[1].strip()
    for l in open("/etc/default/logger").readlines()
    if l.strip()
}

ROTATED_LOG_FOLDER = os.path.join(env["LOG_FOLDER"], "rotated")


def only_rotated_pending(fname):
    return re.match(r"\.\d+", os.path.splitext(fname)[1]) and not os.path.exists(
        "{}.lock".format(fname)
    )


print("Processing logs on", ROTATED_LOG_FOLDER)
for fname in filter(only_rotated_pending, os.listdir(ROTATED_LOG_FOLDER)):
    fpath = os.path.join(ROTATED_LOG_FOLDER, fname)
    print(" .. ", fpath)
    if subprocess.call(["upload-log", fpath]) != 0:
        print(" ... errored")

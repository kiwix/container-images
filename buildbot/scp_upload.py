#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ai ts=4 sts=4 et sw=4 nu

import os
import sys
import subprocess

""" Kiwix nightly builds uploader

    Sends a build file to the nightly builds repository via FTP.
    Usage: script.py password_module source_path dest_folder dest_name

        password_module: path of a python file containing FTP_PASSWD variable
        source_path: path of file to transfer on local machine.
        dest_folder: relative path on FTP server. Usually `latest/`
        dest_name: filename to give on FTP server """

SCP_HOST = "download.kiwix.org"
SCP_USER = "nightlybot"
IS_WIN = os.name == 'nt'


def main(argv):

    if len(argv) != 3:
        print("Usage:\t{0} source_path "
              "destination_folder destination_name\n\n"
              "Missing arguments.".format(sys.argv[0]))
        sys.exit(1)

    source_path, dest_folder, dest_name = argv

    if not os.path.exists(source_path):
        print("source_path not found: {}".format(source_path))

    data = {'sname': source_path,
            'user': SCP_USER,
            'host': SCP_HOST,
            'folder': dest_folder,
            'dname': dest_name}

    subprocess.call("scp {sname} {user}@{host}:{folder}/{dname}".format(**data).split())

    # make sure file is world readable
    return subprocess.call(
        ["ssh", "{user}@{host}".format(**data),
         "\"chmod +rx {folder}/{dname}\"".format(**data)])

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

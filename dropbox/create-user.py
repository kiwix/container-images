#!/usr/bin/python3

""" creates a jailed user """

import argparse
import os
import pathlib
import re
import subprocess
import sys
from typing import Union, List

PASSWD = pathlib.Path("/etc/passwd")
JAILS_ROOT = pathlib.Path("/jails")
KEYS_ROOT = pathlib.Path("/etc/ssh/authorized-keys")
RE_USERNAME = re.compile(r"^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$")


def create_jail(ugid, name):
    jail_path = JAILS_ROOT.joinpath(name)
    if not jail_path.exists():
        jail_path.mkdir(parents=True, exist_ok=True)
    subprocess.run(["/usr/sbin/groupadd", "-g", str(ugid), "-r", name], check=True)
    subprocess.run(
        ["/usr/sbin/jk_init", "-v", "-j", str(jail_path), "rssh", "ssh", "scp", "sftp"],
        check=True,
    )
    subprocess.run(
        [
            "/usr/sbin/useradd",
            "-g",
            name,
            "-u",
            str(ugid),
            "-M",
            "-N",
            "-r",
            "-s",
            "/bin/rssh",
            name,
        ],
        check=True,
    )
    subprocess.run(
        ["/usr/sbin/jk_jailuser", "-m", "-j", jail_path, "-s", "/bin/rssh", name],
        check=True,
    )

    with open(PASSWD, "r") as fh:
        content = fh.read()
    with open(PASSWD, "w") as fh:
        fh.write(content.replace(r"/usr/sbin/jk_chrootsh", "/bin/rssh"))

    jail_path.joinpath("data").mkdir(parents=True, exist_ok=True)
    try:
        os.chown(jail_path.joinpath("data"), uid=ugid, gid=ugid)
    except Exception:
        ...


def create_user(name: str, uid: Union[int, str], keys: List) -> Union[int, None]:

    if not RE_USERNAME.match(name):
        print(f"invalid username: {name}")
        return 2
    if not str(uid).isdigit() or int(uid) < 1000:
        print(f"invalid uid/gid: {uid}")
        return 2

    try:
        create_jail(ugid=uid, name=name)
    except Exception as exc:
        print(f"Error creating user {name}: {exc}")
        return 1

    KEYS_ROOT.mkdir(parents=True, exist_ok=True)
    with open(KEYS_ROOT.joinpath(name), "a") as fh:
        for key in keys:
            fh.write(f"{key}\n")

    return 0


def main():
    parser = argparse.ArgumentParser(prog="create-user", description=__doc__)
    parser.add_argument("-V", "--version", action="version", version="1.0")

    parser.add_argument(help="Username", dest="name")
    parser.add_argument(help="User and group ID", dest="uid", type=int)
    parser.add_argument(
        "--key", help="Public keys to add", dest="keys", default=[], action="append"
    )

    kwargs = dict(parser.parse_args()._get_kwargs())
    sys.exit(create_user(**kwargs))


if __name__ == "__main__":
    sys.exit(main())

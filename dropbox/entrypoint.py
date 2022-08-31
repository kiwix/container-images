#!/usr/bin/python3

""" adds and configures additional, separated users

JSON FORMAT:

[{"id": 1010, "name": "john", "keys": ["ssh-rsa AAAAB3NzaC1yc2EAAAxxxx user@host"]}]

"""

import json
import os
import pathlib
import subprocess
import sys
from typing import Any, Dict, Tuple, List


def validate(user: Dict[str, Any]) -> Tuple[str, int, List]:
    for key, types in [("name", str), ("id", (str, int)), ("keys", list)]:
        if not isinstance(user.get(key), types):
            print(
                f"TypeError for `{key}`: {type(user.get(key))} "
                f"instead of {types} in {user}"
            )
            return

    return user.get("name"), user.get("id"), user.get("keys", [])


def main():

    run_sshd = pathlib.Path("/run/sshd")
    if not run_sshd.exists():
        run_sshd.mkdir(mode=0o755, parents=True, exist_ok=True)

    users_payload = os.getenv("USERS", "")
    if not users_payload:
        print("No “USERS” environment variable. exiting.")
        sys.exit(0)

    try:
        users = json.loads(users_payload)
    except Exception as exc:
        print(f"Unable to parse “USERS” JSON payload: {exc}")
        sys.exit(1)

    for user in users:
        validated = validate(user)
        if not validated:
            continue
        name, uid, keys = validated

        cmd = ["/usr/local/bin/create-user"]
        for key in keys:
            cmd += ["--key", key]
        cmd += [name, str(uid)]
        print(f"{cmd=}")
        if subprocess.run(cmd).returncode == 0:
            print(f"User “{name}” created with {len(keys)} public keys allowed")

    print(f"Starting {sys.argv[1]}")
    os.execv(sys.argv[1], sys.argv[1:])  # nosec


if __name__ == "__main__":
    main()

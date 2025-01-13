#!/usr/bin/env python

""" command line to generate a base64-encoded PBKDF2 version of a password

    similar to how qBittorrent stores web-ui password in its config file.
    Format is salt:HMAC"""

import base64
import hashlib
import secrets
import sys


def asb64(data: bytes) -> str:
    return base64.b64encode(data).decode("ASCII")


def get_pbkdf2_for(password: str) -> str:
    salt = secrets.token_bytes(16)
    hmac = hashlib.pbkdf2_hmac(
        hash_name="sha512",
        password=password.encode("UTF-8"),
        salt=salt,
        iterations=100000,
    )
    return f"{asb64(salt)}:{asb64(hmac)}"


def main() -> int:
    if len(sys.argv) != 2:  # noqa: PLR2004
        print(f"Usage: {sys.argv[0]} CLEAR_PASSWORD")  # noqa: T201
        return 1
    print(get_pbkdf2_for(sys.argv[1]))  # noqa: T201
    return 0


if __name__ == "__main__":
    sys.exit(main())

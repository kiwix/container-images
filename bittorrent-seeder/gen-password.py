#!/usr/bin/env python

"""command line to generate a short (8chars) password from alphanum"""

import secrets
import string
import sys


def gen_password() -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(8))


def main() -> int:
    print(gen_password())  # noqa: T201
    return 0


if __name__ == "__main__":
    sys.exit(main())

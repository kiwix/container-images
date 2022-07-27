#!/usr/bin/env python3

import json
import os
import sys
import time

import requests

API_URL = os.getenv("ZIMFARM_API_URL", "https://api.farm.openzim.org/v1")
TEMPLATE = """[__KEY__]
 enabled = yes
 default history = 2592000
 default memory = dbengine
 health enabled by default = auto
 timeout seconds = 60
 buffer size bytes = 1048576
 reconnect delay seconds = 5
 initial clock resync iterations = 60
 multiple connections = allow
 allow from = *

"""


def get_token():
    req = requests.post(
        url=f"{API_URL}/auth/authorize",
        headers={
            "username": os.getenv("ZIMFARM_USERNAME", "n/a"),
            "password": os.getenv("ZIMFARM_PASSWORD", "n/a"),
            "Content-type": "application/json",
        },
    )
    req.raise_for_status()
    return req.json().get("access_token")  # , req.json().get("refresh_token")


def query_api(token, method, path, payload=None, params=None, headers=None, attempt=0):
    url = f"{API_URL}{path}"
    req_headers = {}
    req_headers.update(headers if headers else {})
    try:
        req_headers.update(
            {"Authorization": f"Token {token}", "Content-type": "application/json"}
        )
        req = getattr(requests, method.lower(), "get")(
            url=url, headers=req_headers, json=payload, params=params
        )
    except Exception as exc:
        attempt += 1
        print(f"ConnectionError (attempt {attempt}) for {method} {url} -- {exc}")
        if attempt <= 3:
            time.sleep(attempt * 60 * 2)
            return query_api(token, method, url, payload, params, headers, attempt)
        return (False, 599, f"ConnectionError -- {exc}")

    if req.status_code == requests.codes.NO_CONTENT:
        return True, req.status_code, ""

    try:
        resp = req.json() if req.text else {}
    except json.JSONDecodeError:
        return (
            False,
            req.status_code,
            f"ResponseError (not JSON): -- {req.text}",
        )
    except Exception as exc:
        return (
            False,
            req.status_code,
            f"ResponseError -- {exc} -- {req.text}",
        )

    if req.status_code in (
        requests.codes.OK,
        requests.codes.CREATED,
        requests.codes.ACCEPTED,
    ):
        return True, req.status_code, resp

    if "error" in resp:
        content = resp["error"]
        if "error_description" in resp:
            content += "\n"
            content += str(resp["error_description"])
    else:
        content = str(resp)

    return (False, req.status_code, content)


def main():

    fingerprints = []
    token = get_token()

    def get_from_api(path):
        nonlocal token
        attempts = 0
        while attempts <= 1:
            success, status_code, response = query_api(token, "GET", path)
            attempts += 1

            # Unauthorised error: attempt to re-auth as scheduler might have restarted?
            if status_code == requests.codes.UNAUTHORIZED:
                token = get_token()
                continue
            else:
                break

        if not success:
            raise IOError(f"ERROR HTTP {status_code}: {response}")

        return response

    for user in get_from_api("/users/").get("items", []):
        if user.get("role") != "worker":
            continue
        for ssh_key in get_from_api(f"/users/{user['username']}").get("ssh_keys", []):
            fingerprints.append(ssh_key.get("fingerprint"))

    content = ""
    for fingerprint in fingerprints:
        key = (
            f"{fingerprint[0:8]}-{fingerprint[8:12]}-{fingerprint[12:16]}"
            f"-{fingerprint[16:20]}-{fingerprint[20:]}"
        ).upper()
        content += TEMPLATE.replace("__KEY__", key)
    print(content)


if __name__ == "__main__":
    sys.exit(main())

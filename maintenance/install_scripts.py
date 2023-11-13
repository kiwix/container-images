#!/usr/bin/env python3

r""" Downloads and installs scripts from URLs in INSTALL_SCRIPTS and PIP_INSTALL

    Allows docker image to be dynamically populated with scripts and dependencies

    /!\  don't use it outside of a controlled container environment.
    Flexibility is king here so anyone able to set environment could do **anything**
    to the system running it: upload environ, secret, data, replace system bins, etc.

    INSTALL_SCRIPTS is a line-separated (\n) list of URLs or <name>#<url> should
    you want to customize the filename/path on the container.

    URL can be in the form github://<repo>/<in-repo-path>

    PIP_INSTALL is passed directly to pip install.
    Example: -e PIP_INSTALL='"black>=19,<22.3.0" "ipython==8.2.0"' -r /mnt/reqs.txt"""

import json
import os
import pathlib
import re
import subprocess
import sys
import traceback
import urllib.parse
import urllib.request

TARGET_FOLDER = pathlib.Path(os.getenv("INSTALL_SCRIPTS_TO", "/usr/local/bin"))


def get_main_branch(repository):
    url = "https://api.github.com/repos/{repository}".format(repository=repository)
    with urllib.request.urlopen(url) as uh: # nosec B310
        return json.load(uh).get("default_branch", None)


def expand_url(url):
    uri = urllib.parse.urlparse(url)
    if uri.scheme == "github":
        path = pathlib.Path(uri.path[1:])
        repo = f"{uri.netloc}/{path.parts[0]}"
        branch = get_main_branch(repo)
        return (
            f"https://raw.githubusercontent.com/{repo}/{branch}"
            f"/{'/'.join(path.parts[1:])}"
        )
    else:
        return uri.geturl()


def to_script_tuple(line):
    if "#" in line:
        name, url = line.split("#", 1)
        return name.strip(), expand_url(url.strip())
    url = expand_url(line)
    return pathlib.Path(urllib.parse.urlparse(url).path).name, url


def install_script(name, url):
    fpath = TARGET_FOLDER / name
    with urllib.request.urlopen(url) as resp: # nosec B310
        if resp.status != 200:
            raise ValueError(
                "Unexpected HTTP {resp.status}/{resp.reason} from {url}"
            )
        contenttype = resp.getheader("Content-Type")
        if contenttype and (
            not contenttype.startswith("text/plain")
            and not contenttype.startswith("application/octet-stream")
        ):
            raise ValueError(f"Unexpected Content-Type: {contenttype} from {url}")
        with open(fpath, "wb") as fh:
            fh.write(resp.read())
    fpath.chmod(0o755)
    return fpath


def main(args):

    pip_reqs = os.getenv("PIP_INSTALL", "")
    if pip_reqs:
        print(f"Installing python dependencies: {pip_reqs}")
        subprocess.run(
            " ".join([sys.executable, "-m", "pip", "install", pip_reqs]),
            check=True,
            shell=True, # nosec B602 # allows using quotes to specify versions and ranges
        )

    for line in re.split(r"\r?\n", os.getenv("INSTALL_SCRIPTS", "")):
        if not line:
            continue
        try:
            name, url = to_script_tuple(line.strip())
            script = install_script(name, url)
            print(f"Installed {script} from {url}")
        except Exception as exc:
            print(f"Unable to install script from {line} -- {exc}")
            print("---")
            traceback.print_exc()
            sys.exit(1)

    # flush stdout before replacing current process
    sys.stdout.flush()

    # can be used as entrypoint as well
    if args:
        os.execvp(args[0], args) # nosec B606


if __name__ == "__main__":
    main(sys.argv[1:])

#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ai ts=4 sts=4 et sw=4 nu

"""
FR OK  |   567KiB/s
DE OK  |   336KiB/s
SE OK  |   277KiB/s
DK OK  |   269KiB/s
NL OK  |   259KiB/s
TN OK  |   207KiB/s
"""

import pathlib
import datetime
import subprocess

file = "zim/other/archlinux_en_all_maxi_2020-02.zim"
mirrors = {
    "TN": "http://wiki.mirror.tn/",
    "FR": "http://mirror.download.kiwix.org/",
    "DE": "https://ftp.fau.de/kiwix/",
    "DK": "https://mirrors.dotsrc.org/kiwix/",
    "GB": "https://www.mirrorservice.org/sites/download.kiwix.org/",  # zim (limited)
    "NL": "https://ftp.nluug.nl/pub/kiwix/",
    "SE": "https://ftp.acc.umu.se/mirror/kiwix.org/",
    "IL": "https://mirror.isoc.org.il/pub/kiwix/",  # zim
    "US1": "https://dumps.wikimedia.org/kiwix/",  # zim
    "US2": "https://ftpmirror.your.org/pub/kiwix/",  # zim
}


def download_aria(url, dest, concurrency=4):
    start = datetime.datetime.now()
    aria = subprocess.run(
        [
            "aria2c",
            "-j",
            str(concurrency),
            "-d",
            str(dest.parent),
            "-o",
            str(dest.name),
            url,
        ]
    )
    end = datetime.datetime.now()
    duration = end - start
    if aria.returncode != 0:
        print(f"ERROR downloading {url}")
    return aria.returncode == 0, duration.total_seconds()


def main(download_folder="~/data"):
    durations = []
    for mirror, url in mirrors.items():
        print(mirror)
        dest = (
            pathlib.Path(download_folder)
            .expanduser()
            .resolve()
            .joinpath(f"{mirror}_file.zim")
        )
        success, duration = download_aria(f"{url}{file}", dest)
        if success:
            durations.append((mirror, duration))

    for mirror, duration in sorted(durations, key=lambda x: x[1], reverse=True):
        print(mirror, duration / 60)


if __name__ == "__main__":
    main()

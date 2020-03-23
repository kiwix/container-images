#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ai ts=4 sts=4 et sw=4 nu

# CONFIG
TARGET_FOLDER = "/data"
DOWNLOAD_FILE = "all-downloads.txt"
USE_MIRROR = True
USE_TORRENT = True  # overwrites USE_MIRROR
MIRROR = "http://mirror.download.kiwix.org"

# CONSTANTS
NO_MIRROR = "http://download.kiwix.org"
WIKIPEDIA = "wikipedia"
WIKIPEDIA = "wikipedia"
VIKIDIA = "vikidia"
WIKTIONARY = "wiktionary"
WIKIBOOKS = "wikibooks"
GUTENBERG = "gutenberg"
WIKISOURCE = "wikisource"
OTHER = "other"

all_urls = []


def geturl(path):
    if USE_TORRENT or not USE_MIRROR:
        base = NO_MIRROR
    else:
        base = MIRROR
    url = base + path
    if USE_TORRENT:
        url += ".torrent"
    return url


# non-zim contents
files = [
    # KA-lite FR
    "/other/kalite/langpack_fr_0.17.zip",
    "/other/kalite/videos_fr_0.17.tar",
    # KA-lite EN
    "/other/kalite/langpack_en_0.17.zip",
    "/other/kalite/videos_en_0.17.tar",
]

for file in files:
    pass
    all_urls.append(geturl(file))

zims = [
    (WIKIPEDIA, "wikipedia_fr_all_maxi_2019-12"),
    (WIKIPEDIA, "wikipedia_en_all_nopic_2019-12"),
    (WIKIPEDIA, "wikipedia_ar_all_maxi_2020-01"),
    (VIKIDIA, "vikidia_fr_all_maxi_2019-12"),
    (VIKIDIA, "vikidia_en_all_maxi_2020-03"),
    (WIKTIONARY, "wiktionary_fr_all_maxi_2020-03"),
    (WIKTIONARY, "wiktionary_en_all_maxi_2020-01"),
    (WIKTIONARY, "wiktionary_ar_all_maxi_2020-02"),
    (WIKIBOOKS, "wikibooks_fr_all_maxi_2020-03"),
    (WIKIBOOKS, "wikibooks_en_all_maxi_2020-03"),
    (WIKIBOOKS, "wikibooks_ar_all_maxi_2020-02"),
    (GUTENBERG, "gutenberg_fr_all_2018-10"),
    (GUTENBERG, "gutenberg_en_all_2018-10"),
    (WIKISOURCE, "wikisource_fr_all_maxi_2020-03"),
]

for folder, zim_name in zims:
    file = "{zim}.zim".format(zim=zim_name)
    all_urls.append(geturl("/zim/{folder}/{file}".format(folder=folder, file=file)))

with open(DOWNLOAD_FILE, "w") as fh:
    for url in all_urls:
        fh.write("{}\n".format(url))

print("Please launch aria2 using the following command (in a screen)\n")
command = ["aria2c", "-d", TARGET_FOLDER, "-c", "-j", "20", "-i", DOWNLOAD_FILE]
print(" ".join(command))

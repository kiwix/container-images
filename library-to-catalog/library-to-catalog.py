#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ai ts=4 sts=4 et sw=4 nu

from __future__ import (unicode_literals, absolute_import,
                        division, print_function)
import re
import os
import sys
import logging
import hashlib
import xml.etree.ElementTree as ET

import yaml
import requests
import pycountry

try:
    text_type = unicode  # Python 2
    from urlparse import urlparse, urljoin
except NameError:
    text_type = str      # Python 3
    from urllib.parse import urlparse, urljoin

LABELS = {
    'nopic': "NO PICTURE",
    'novid': "NO VIDEO",
    '_ftindex': "Full-text index",
    'nodet': "NO DET",
}

logging.basicConfig()
logger = logging.getLogger("library2yaml")
logger.setLevel(logging.DEBUG)

with_checksum = True  # debug only
with_size = True  # debug only
use_zip = False


def get_remote_checksum(url):
    ''' retrieve SHA-256 checksum of download using special mirrorbrain url '''
    req = requests.get("{url}.sha256".format(url=url))
    return req.text.split()[0]


def get_remote_checksum_from_header(url):
    ''' retrieves SHA-256 checksum of url from its headers (mirrorbrain)

        not using because it is encoded (looks like base64 but it's not) '''
    req = requests.head(url)
    for digest_line in req.headers['Digest'].split():
        if digest_line.startswith("SHA-256"):
            return digest_line.split("=", 1)[-1]


def get_local_checksum(fpath):
    ''' calculate SHA-256 checksum from a local file '''
    hash_sha = hashlib.sha256()
    with open(fpath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_sha.update(chunk)
    return hash_sha.hexdigest()


def get_remote_size(url):
    ''' retrieves file size in bytes from its headers '''
    req = requests.head(url, allow_redirects=True)
    return int(req.headers['Content-Length'])


def get_local_size(fpath):
    ''' size in bytes of a local file '''
    return os.path.getsize(fpath)


def get_zip_url(url):
    ''' convert .zim.meta4 url to .zip one '''
    purl = urlparse(url)
    path = purl.path
    fname = os.path.basename(url)
    dirent = path[:len(path) - len(fname)]

    new_fname = "kiwix-0.9+{fname}".format(
        fname=re.sub(r'\.zim\.meta4$', '.zip', fname))
    new_dirent = dirent.replace("/zim/", "/portable/")
    new_path = "{dirent}{fname}".format(dirent=new_dirent, fname=new_fname)
    return urljoin(url, new_path)


def get_zim_url(url):
    ''' convert .zim.meta4 url to .zim one '''
    purl = urlparse(url)
    path = purl.path
    fname = os.path.basename(url)
    dirent = path[:len(path) - len(fname)]

    new_fname = re.sub(r'\.zim\.meta4$', '.zim', fname)
    new_path = "{dirent}{fname}".format(dirent=dirent, fname=new_fname)
    return urljoin(url, new_path)


def clean(text):
    ''' normalize free text input from library (titles, descriptions) '''
    if text is None:
        return None
    return " ".join(text.splitlines())


def get_attr(book, key, t=text_type):
    ''' attribute accessor for XML element '''
    value = book.attrib.get(key)
    if value is None:
        return None
    return t(value)


def get_kind(book):
    ''' main descriptor of conent (wikipedia, wiktionary, etc)

        derivate from fname '''

    fname = os.path.basename(get_attr(book, 'url'))
    return re.sub(r'_20[0-9]{2}\-[0-1][0-9]\.zim\.meta4$', '', fname)


def read_tags(book):
    ''' cleaned-up list of tags from XML book '''
    return list(set([tag.replace('"', '').replace('=', '')
                     for tag in (get_attr(book, 'tags') or "").split(';')]))


def get_tags_label(tags):
    ''' label describing important tags features '''
    if not tags:
        return None
    labels = [LABELS.get(tag) for tag in tags if tag in LABELS.keys()]
    if not labels:
        return None
    return ", ".join(labels)


def convert(library_fpath, catalog_fpath,
            format='zim', local_repository=False):

    logger.info("starting convertion of `{}` to `{}`"
                .format(library_fpath, catalog_fpath))

    if not os.path.exists(library_fpath):
        raise IOError("missing library file `{}`".format(library_fpath))

    tree = ET.parse(library_fpath)
    root = tree.getroot()

    logger.info("parsing xml library file `{}`".format(library_fpath))
    catalog = {}
    for book in root.iter('book'):
        def ga(k, t=text_type):
            return get_attr(book, k, t)

        # copy data from attributes
        version = ga('date')
        name = clean(ga('title'))
        description = clean(ga('description'))
        meta_url = ga('url')  # URL to zim.meta4 file
        bid = ga('id') or "none_not-found-in-library.xml"  # unique book ID

        # update title for tags
        tags = read_tags(book)
        tags_label = get_tags_label(tags)
        if tags_label is not None:
            name = "{name} [{label}]".format(name=name, label=tags_label)

        # language is used in both ISO 639-3 (pol) and ISO 639-1 (pl)
        lang_3 = ga('language')  # xml contains ISO 639-3

        # skip content without a language code
        #   old 2009 ubuntudoc
        #   wikipedia ml)
        if lang_3 is None:
            continue

        # find ISO 639-1 from ISO 639-3 (might not exist)
        if re.search(r'[^a-z]', lang_3) is not None:
            lang_3 = re.split(r'[^a-z]', lang_3, 1)[0]
        try:
            lang_1 = pycountry.languages.get(**{
                'alpha_{}'.format(len(lang_3)): lang_3}).alpha_2
        except (AttributeError, KeyError):
            lang_1 = lang_3

        # url to final content file
        url = get_zip_url(meta_url) if use_zip else get_zim_url(meta_url)

        # size and checksums are either captured over network or using
        # a local copy of all the files.
        if local_repository:
            full_path = urlparse(url).path
            fname = os.path.basename(url)
            short_path = full_path[:-len(fname)]
            fpath = os.path.join(local_repository, short_path[1:], fname)
        else:
            full_path = fname = short_path = None

        size = None
        if with_size:
            # size in library is approx in KB. ideascube wants accurate bytes
            if local_repository and os.path.exists(fpath):
                size = get_local_size(fpath)
            if size is None:
                logger.debug("fetching size for {}".format(url))
                size = get_remote_size(url)
        else:
            size = ga('size', int) * 1024

        # catalog expects an SHA256 checksum of the content
        sha256sum = None
        if with_checksum:
            if local_repository and os.path.exists(fpath):
                logger.debug("calculating local checksum for {}".format(fpath))
                sha256sum = get_local_checksum(fpath)
            if sha256sum is None:
                logger.debug("fetching checkum for {}".format(url))
                sha256sum = get_remote_checksum(url)

        # catalog expects either zipped-zim or zim
        btype = "zipped-zim" if use_zip else "zim"

        # identifiers
        kind = get_kind(book)
        if lang_1 is not None:
            langid = "{kind}.{lang}".format(kind=kind, lang=lang_1)
        else:
            langid = kind

        catalog[langid] = {
            'name': name,
            'description': description,
            'version': version,
            'language': lang_3,
            'id': bid,
            'url': url,
            'size': size,
            'sha256sum': sha256sum,
            'type': btype,
            'langid': langid,
        }

    logger.info("finished parsing {nb} entries".format(nb=len(catalog.keys())))

    logger.info("dumping yaml content to file `{}`".format(catalog_fpath))
    with open(catalog_fpath, 'w') as fd:
        yaml.safe_dump({'all': catalog}, fd,
                       default_flow_style=False,
                       allow_unicode=True,
                       encoding="utf-8")

    logger.info("done converting library to catalog.")


if __name__ == '__main__':
    if not len(sys.argv[1:]) == 2:
        logger.error("Usage: {} library.xml catalog.yml [zim|zip]"
                     .format(sys.argv[0]))
        sys.exit(1)

    try:
        convert(*sys.argv[1:])
    except Exception as exp:
        logger.critical("Unhandled exception raised during convertion.")
        logger.exception(exp)
        logger.error("library file was not converted.")
        sys.exit(1)

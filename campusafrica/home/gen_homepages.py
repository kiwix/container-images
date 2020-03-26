# -*- coding: utf-8 -*-
# vim: ai ts=4 sts=4 et sw=4 nu

"""
virtualenv -p python3 venv
source venv/bin/activate
pip install -U pip Jinja2==2.10.1 PyYAML==4.2b4 requests==2.23.0
"""

import os
import sys
import json
import random
import pathlib

import yaml
import requests
from jinja2 import Environment, FileSystemLoader, select_autoescape

FQDN = os.getenv("FQDN", "kiwix.campusafrica.gos.orange.com")
YAML_CATALOGS = None


def fetch_catalogs(catalog_path):
    """ build a dict of loaded (yaml) catalogs from CATALOGS """
    parsed_catalog_file = pathlib.Path(catalog_path.stem + ".json")
    if parsed_catalog_file.exists():
        with open(parsed_catalog_file, "r") as fh:
            return json.load(fh)
    catalogs = []
    try:
        with open(catalog_path, "r") as fp:
            catalogs.append(yaml.load(fp.read()))

        # ensure the content is readable (prevent incorrect encoding)
        entry = catalogs[-1]["all"][random.choice(list(catalogs[-1]["all"].keys()))]
        for key in (
            "name",
            "description",
            "version",
            "language",
            "id",
            "url",
            "sha256sum",
            "type",
            "langid",
        ):
            if not entry.get(key) or not isinstance(entry[key], str):
                print("Catalog format is not valid")
                catalogs.pop()  # remove catalog from list
                break
    except Exception as exp:
        print("Exception while downloading/parsing catalogs: {}".format(exp))
        return None
    with open(parsed_catalog_file, "w") as fh:
        json.dump(catalogs, fh, indent=4)
    return catalogs if len(catalogs) else None


def get_package(package_id):
    for catalog in YAML_CATALOGS:
        if package_id in catalog["all"].keys():
            return catalog["all"][package_id]


def get_domain(name):
    return name.replace(" ", "_").replace("_", "-").lower()


def language_is_bidirectional(lang_code):
    return lang_code in ("ar",)


jinja_env = Environment(
    loader=FileSystemLoader("."), autoescape=select_autoescape(["html", "xml", "txt"]),
)
jinja_env.filters["language_bidi"] = language_is_bidirectional


def generate_homepage(name, language=None, fqdn=FQDN, **options):
    """ generate an ideascube lookalike HTML homepage from options

        {
         "name": "Kiwix – Campus Africa"
         "kalite": True,
         "packages": [],
        }
    """
    cards = []

    if options.get("kalite"):
        kalite_fqdn = "khan-{language}.{fqdn}".format(language=language, fqdn=fqdn)
        if language == "fr":
            cards.append(
                {
                    "url": "//{}/go/fr".format(kalite_fqdn),
                    "css_class": "khanacademy",
                    "category_class": "learn",
                    "category": "Apprendre",
                    "title": "Khan Academy",
                    "description": "Apprendre via des vidéos et des exercices.",
                }
            )
        if language == "es":
            cards.append(
                {
                    "url": "//{}/go/es".format(kalite_fqdn),
                    "css_class": "khanacademy",
                    "category_class": "learn",
                    "category": "Aprender",
                    "title": "Khan Academy",
                    "description": "Aprende con videos y ejercicios.",
                }
            )
        if language == "en":
            cards.append(
                {
                    "url": "//{}/go/en".format(kalite_fqdn),
                    "css_class": "khanacademy",
                    "category_class": "learn",
                    "category": "Learn",
                    "title": "Khan Academy",
                    "description": "Learn with videos and exercises.",
                }
            )

    if options.get("packages"):
        kiwix_fqdn = "zims-{language}.{fqdn}".format(fqdn=fqdn, language=language)
        for package_id in options.get("packages"):
            package = get_package(package_id)
            urlid = package.get("langid", package_id).rsplit(".", 1)[0]
            cards.append(
                {
                    "url": "//{fqdn}/{id}".format(fqdn=kiwix_fqdn, id=urlid),
                    "css_class": "zim_{}".format(package_id.rsplit(".", 1)[0]),
                    "category_class": "read",
                    "category": "ZIM",
                    "title": package.get("name"),
                    "description": package.get("description"),
                    "fa": "",
                }
            )
    context = {
        "name": name,
        "cards": cards,
        "language": language,
        "main_page": language is None,
        "languages": options.get("languages", []),
    }
    content = jinja_env.get_template("home_template.html").render(**context)
    return content


def identifiers_from_zimfiles(zim_dir):
    identifiers = []
    if not zim_dir.exists():
        return identifiers
    for file in zim_dir.iterdir():
        if file.suffix == ".zim":
            cid = file.stem.rsplit("_", 1)[0]
            lang = file.stem.split("_", 2)[1]
            identifiers.append("{id}.{lang}".format(id=cid, lang=lang))
    return identifiers


def generate_options(data_dir, languages):
    options = {language: {} for language in languages}

    for language in languages:
        options[language]["kalite"] = data_dir.joinpath("kalite", language).exists()

        options[language]["packages"] = identifiers_from_zimfiles(
            data_dir.joinpath("packages", language)
        )

    return options


def generate_homepages(data_dir, languages):
    langs = [lang[0] for lang in languages]
    html_dir = data_dir.joinpath("html")
    options = generate_options(data_dir, langs)

    for language in langs:
        print("homepage for", language)
        html_content = generate_homepage("Campus", language, **options[language])

        html_dir = data_dir.joinpath("html", language)
        os.makedirs(html_dir, exist_ok=True)
        with open(html_dir.joinpath("index.html"), "w") as fp:
            fp.write(html_content)

        for package_id in options[language].get("packages", []):
            package = get_package(package_id)
            urlid = package.get("langid", package_id).rsplit(".", 1)[0]
            favicon = html_dir.joinpath("zim_{}.png".format(urlid))
            if not favicon.exists():
                req = requests.get(
                    "http://library.kiwix.org/{}/-/favicon".format(urlid)
                )
                with open(favicon, "wb") as fh:
                    fh.write(req.content)
        khan_favicon = html_dir.joinpath("khanacademy.png")
        if not khan_favicon.exists():
            src = pathlib.Path(__file__).parent.joinpath("khanacademy.png")
            khan_favicon.write_bytes(src.read_bytes())

        # kiwix-serve external override
        context = {
            "name": "",
            "external": True,
            "language": language,
        }
        html_content = jinja_env.get_template("home_template.html").render(**context)
        html_dir = data_dir.joinpath("html", language, "external")
        os.makedirs(html_dir, exist_ok=True)
        with open(html_dir.joinpath("index.html"), "w") as fp:
            fp.write(html_content)

    # main homepage
    print("main homepage")
    html_content = generate_homepage("Campus", None, languages=languages)
    html_dir = data_dir.joinpath("html")
    os.makedirs(html_dir, exist_ok=True)
    with open(html_dir.joinpath("index.html"), "w") as fp:
        fp.write(html_content)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("missing data path")
        sys.exit(1)

    print("parse catalog")
    YAML_CATALOGS = fetch_catalogs(pathlib.Path("ideascube.yml"))
    print(".. done")
    generate_homepages(
        pathlib.Path(sys.argv[1]),
        [("fr", "Français"), ("en", "English"), ("ar", "عربى")],
    )

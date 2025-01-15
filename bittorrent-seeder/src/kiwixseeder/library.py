import collections
import datetime
import os
import re
import urllib.parse
from collections.abc import Generator
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, ClassVar
from uuid import UUID

import iso639
import xmltodict
from iso639.exceptions import DeprecatedLanguageValue, InvalidLanguageValue

from kiwixseeder.context import Context
from kiwixseeder.download import get_btih_from_url, session
from kiwixseeder.utils import format_size, get_cache_path

UPDATE_EVERY_SECONDS: int = int(os.getenv("UPDATE_EVERY_SECONDS", "3600"))

context = Context.get()
logger = context.logger


def to_human_id(name: str, publisher: str | None = "", flavour: str | None = "") -> str:
    """periodless exchange identifier for ZIM Title"""
    publisher = publisher or "openZIM"
    flavour = flavour or ""
    return f"{publisher}:{name}:{flavour}"


class BookBtihMapper:
    """ Disk-cached mapping of Book UUID to BT Info Hash

        Required since btih is not a Catalog metadata but necessary to reconcile
        torrents with books uniquely"""

    # maps {uuid: str} to {btih: str}
    data: ClassVar[dict[str, str]] = {}
    last_read: datetime.datetime = datetime.datetime(2000, 1, 1, tzinfo=datetime.UTC)

    @classmethod
    def read(cls, *, force: bool = False):
        if not force and cls.last_read + datetime.timedelta(
            60
        ) >= datetime.datetime.now(tz=datetime.UTC):
            return
        folder = get_cache_path("zim-btih-maps")
        folder.mkdir(parents=True, exist_ok=True)
        data = {
            fpath.name.split(":", 1)[0]: fpath.name.split(":", 1)[1]
            for fpath in folder.iterdir()
            if ":" in fpath.name
        }
        cls.data = data

    @classmethod
    def write(cls):
        folder = get_cache_path("zim-btih-maps")
        folder.mkdir(parents=True, exist_ok=True)
        for uuid, btih in cls.data:
            folder.joinpath(f"{uuid}:{btih}").touch()

    @classmethod
    def get(cls, uuid: UUID) -> str | None:
        cls.read()
        return cls.data.get(uuid.hex)

    @classmethod
    def add(cls, uuid: UUID, btih: str):
        uuids = uuid.hex
        if uuids in cls.data:
            return
        cls.data[uuids] = btih
        folder = get_cache_path("zim-btih-maps")
        folder.mkdir(parents=True, exist_ok=True)
        folder.joinpath(f"{uuids}:{btih}").touch()



@dataclass(kw_only=True)
class Book:
    uuid: UUID
    ident: str
    name: str
    title: str
    description: str
    author: str
    publisher: str
    langs_iso639_1: list[str] = field(default_factory=list)
    langs_iso639_3: list[str]
    tags: list[str]
    flavour: str
    size: int
    url: str
    illustration_relpath: str
    version: str
    last_seen_on: datetime.datetime
    _btih: str

    def __post_init__(self):
        for lang in list(self.langs_iso639_3):
            value: str = lang
            try:
                value = iso639.Lang(lang).pt1
            # skip language if code is invalid or deprecated
            except (
                DeprecatedLanguageValue,
                InvalidLanguageValue,
            ):
                self.langs_iso639_3.remove(lang)
                continue
            self.langs_iso639_1.append(value)

        # fallback to eng if no valid code was supplied
        if not self.langs_iso639_3:
            self.langs_iso639_3.append("eng")
        if not self.langs_iso639_1:
            self.langs_iso639_1.append("en")

    @property
    def category(self) -> str:
        try:
            return next(
                tag.split(":", 1)[1]
                for tag in self.tags
                if tag.startswith("_category:")
            )
        except StopIteration:
            return ""

    @property
    def filepath(self) -> Path:
        return Path(urllib.parse.urlparse(self.url).path)

    @property
    def filename(self) -> str:
        return Path(urllib.parse.urlparse(self.url).path).name

    @property
    def torrent_url(self) -> str:
        return f"{self.url}.torrent"

    @property
    def lang_codes(self) -> list[str]:
        return self.langs_iso639_3

    @property
    def lang_code(self) -> str:
        return self.langs_iso639_3[0]

    @property
    def language(self) -> iso639.Lang:
        return iso639.Lang(self.lang_code)

    @property
    def btih(self) -> str:
        if not self._btih:
            if btih := BookBtihMapper.get(self.uuid):
                self._btih = btih
            else:
                # use setter so it gets cached
                self.btih = get_btih_from_url(self.torrent_url)
        return self._btih

    @btih.setter
    def btih(self, value: str):
        BookBtihMapper.add(self.uuid, value)
        self._btih = value

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    def __str__(self) -> str:
        return (
            f"{self.ident} @ {self.version} "  # noqa: RUF001
            f"({format_size(self.size)})"
        )


class Catalog:
    def __init__(self):
        # list of Book by ident
        self._books: dict[str, Book] = {}
        # list of book-idents by language (ISO-639-1)
        self._by_langs: dict[str, list[str]] = {}
        self.updated_on: datetime.datetime = datetime.datetime(
            1970, 1, 1, tzinfo=datetime.UTC
        )
        BookBtihMapper.read(force=True)

    def __contains__(self, ident: str) -> bool:
        return ident in self.get_all_ids()

    @property
    def all_books(self) -> Generator[Book, None, None]:
        self.ensure_fresh()
        yield from self._books.values()

    @property
    def nb_books(self) -> int:
        self.ensure_fresh()
        return len(self._books)

    @property
    def languages(self) -> collections.OrderedDict[str, str]:
        overrides = {
            "ina": "Interlingua",
        }
        return collections.OrderedDict(
            sorted(
                [
                    (
                        lang,
                        overrides.get(lang, iso639.Lang(lang).name),
                    )
                    for lang in self._by_langs.keys()
                ],
                key=lambda x: x[1],
            )
        )

    def get(self, ident: str) -> Book:
        self.ensure_fresh()
        return self._books[ident]

    def get_or_none(self, ident: str) -> Book | None:
        self.ensure_fresh()
        return self._books.get(ident)

    def get_all_ids(self) -> Generator[str, None, None]:
        self.ensure_fresh()
        yield from self._books.keys()

    def get_for_lang(self, lang_code: str) -> Generator[Book, str, None]:
        self.ensure_fresh()
        for ident in self._by_langs.get(lang_code, []):
            yield self.get(ident)

    def reset(self):
        self._books.clear()
        self._by_langs.clear()
        self.updated_on: datetime.datetime = datetime.datetime(
            1970, 1, 1, tzinfo=datetime.UTC
        )

    def ensure_fresh(self):
        # only refresh library if it reachs a configured age
        if self.updated_on < datetime.datetime.now(datetime.UTC) - datetime.timedelta(
            seconds=UPDATE_EVERY_SECONDS
        ):
            self.do_refresh()

    def do_refresh(self):
        logger.debug(f"refreshing catalog via {context.catalog_url}")
        books: dict[str, Book] = {}
        langs: dict[str, list[str]] = {}
        try:
            resp = session.get(
                f"{context.catalog_url}/entries", params={"count": "-1"}, timeout=30
            )
            resp.raise_for_status()
            fetched_on = datetime.datetime.now(datetime.UTC)
            catalog = xmltodict.parse(resp.content)
            if "feed" not in catalog:
                raise ValueError("Malformed OPDS response")
            if not int(catalog["feed"]["totalResults"]):
                raise OSError("Catalog has no entry; probably misbehaving")
            for entry in catalog["feed"]["entry"]:
                if not entry.get("name"):
                    logger.warning(f"Skipping entry without name: {entry}")
                    continue

                links = {link["@type"]: link for link in entry["link"]}
                version = datetime.datetime.fromisoformat(
                    re.sub(r"[A-Z]$", "", entry["updated"])
                ).strftime("%Y-%m-%d")
                flavour = entry.get("flavour") or ""
                publisher = entry.get("publisher", {}).get("name") or ""
                author = entry.get("author", {}).get("name") or ""
                ident = to_human_id(
                    name=entry["name"],
                    publisher=publisher,
                    flavour=flavour,
                )
                if not links.get("image/png;width=48;height=48;scale=1"):
                    logger.warning(f"Book has no illustration: {ident}")
                books[ident] = Book(
                    uuid=UUID(entry["id"]),
                    ident=ident,
                    name=entry["name"],
                    title=entry["title"],
                    author=author,
                    publisher=publisher,
                    description=entry["summary"],
                    langs_iso639_3=list(set(entry["language"].split(","))) or ["eng"],
                    tags=list(set(entry["tags"].split(";"))),
                    flavour=flavour,
                    size=int(links["application/x-zim"]["@length"]),
                    url=re.sub(r".meta4$", "", links["application/x-zim"]["@href"]),
                    illustration_relpath=links.get(
                        "image/png;width=48;height=48;scale=1", {}
                    ).get("@href", ""),
                    version=version,
                    last_seen_on=fetched_on,
                    _btih="",
                )
        except Exception as exc:
            logger.error(f"Unable to load catalog from OPDS: {exc}")
            # only fail refresh if we have no previous catalog to use
            if not self._books:
                raise exc
        else:
            # re-order alphabetically by language then title
            books = collections.OrderedDict(
                sorted(
                    ((ident, book) for ident, book in books.items()),
                    key=lambda item: (item[1].language.name, item[1].title),
                )
            )
            for ident in books.keys():
                for lang in books[ident].lang_codes:
                    if lang not in langs:
                        langs[lang] = []
                    langs[lang].append(ident)
            self._books = books
            self._by_langs = langs
            self.updated_on = datetime.datetime.now(datetime.UTC)
            logger.debug(f"refreshed on {self.updated_on}")

import logging
import os
import platform
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Self
from urllib.parse import ParseResult, urlparse

import humanfriendly
import qbittorrentapi

from kiwixseeder.utils import SizeRange


def set_from_env(name: str) -> set[str]:
    """ set() from ENV"""
    return {entry for entry in (os.getenv(name) or "").split("|") if entry}

NAME = "kiwix-seeder"          # must be filesystem-friendly (technical)
CLI_NAME = "kiwix-seeder"
HUMAN_NAME = "Kiwix Seeder"
QBT_CAT_NAME = "kiwix-seeder"  # name of category to group our torrents in
RC_NOFILTER = 32               # exit-code when user has no filter and did not confirm
RC_INSUFFICIENT_STORAGE = 30   # exit-code when store is not enough for selection

CATALOG_URL = os.getenv("CATALOG_URL", "https://library.kiwix.org/catalog/v2")
DOWNLOAD_URL = os.getenv("DOWNLOAD_URL", "https://download.kiwix.org")

DEFAULT_QBT_USERNAME: str | None = os.getenv("QBT_USERNAME")
DEFAULT_QBT_PASSWORD: str | None = os.getenv("QBT_PASSWORD")
DEFAULT_QBT_HOST: str = os.getenv("QBT_HOST") or "localhost"
DEFAULT_QBT_PORT: int = int(os.getenv("QBT_PORT") or "8080")
DEFAULT_MAX_STORAGE: int = humanfriendly.parse_size(os.getenv("MAX_STORAGE") or "10GiB")
DEFAULT_KEEP_DURATION: float = humanfriendly.parse_timespan(
    os.getenv("KEEP_DURATION") or "12w"
)
DEFAULT_SLEEP_INTERVAL: float = humanfriendly.parse_timespan(
    os.getenv("SLEEP_INTERVAL") or "5m"
)

DEFAULT_FILTER_FILENAMES: set[str] = set_from_env("FILENAMES")
DEFAULT_FILTER_LANGUAGES: set[str] = set_from_env("LANGUAGES")
DEFAULT_FILTER_CATEGORIES: set[str] = set_from_env("CATEGORIES")
DEFAULT_FILTER_FLAVOURS: set[str] = set_from_env("FLAVOURS")
DEFAULT_FILTER_TAGS: set[str] = set_from_env("TAGS")
DEFAULT_FILTER_AUTHORS: set[str] = set_from_env("AUTHORS")
DEFAULT_FILTER_PUBLISHERS: set[str] = set_from_env("PUBLISHERS")
try:
    min_size: int = humanfriendly.parse_size(os.getenv("MIN_SIZE") or "0")
except humanfriendly.InvalidSize:
    min_size: int = 0
try:
    max_size: int = humanfriendly.parse_size(os.getenv("MAX_SIZE") or "")
except humanfriendly.InvalidSize:
    max_size: int = 0
DEFAULT_FILTER_FILESIZES: SizeRange = SizeRange(minimum=min_size, maximum=max_size)
DEFAULT_DEBUG: bool = bool(os.getenv("DEBUG"))
SEED_WHOLE_CATALOG: bool = bool(os.getenv("SEED_WHOLE_CATALOG"))

# avoid debug-level logs of 3rd party deps
for module in ("urllib3", "qbittorrentapi.request"):
    logging.getLogger(module).setLevel(logging.INFO)


@dataclass(kw_only=True)
class QbtConnection:
    """ Abstraction over qBittorrent Connection

    Supports input as URI or individual parts and exposes them"""
    username: str | None
    password: str | None
    host: str
    port: int

    @classmethod
    def using(cls, string: str) -> Self:
        """ Init from a qbt-schemed URI"""
        uri = urlparse(string)
        if uri.scheme not in ("http", "https"):
            raise ValueError(f"Malformed HHTP(s) URL: {string}")
        return cls(
            username=uri.username,
            password=uri.password,
            host=uri.hostname or "localhost",
            port=uri.port or 80,
        )

    def __str__(self) -> str:
        return ParseResult(
            scheme="http",
            netloc=f"{self.username or ''}"
            f"{':' if self.password else ''}{self.password or ''}"
            f"@{self.host}:{self.port}",
            path="",
            params="",
            query="",
            fragment="",
        ).geturl()


DEFAULT_QBT_CONN = str(
    QbtConnection.using(str(os.getenv("QBT_URL")))
    if os.getenv("QBT_URL")
    else QbtConnection(
        username=DEFAULT_QBT_USERNAME,
        password=DEFAULT_QBT_PASSWORD,
        host=DEFAULT_QBT_HOST,
        port=DEFAULT_QBT_PORT,
    )
)


@dataclass(kw_only=True)
class Context:

    # singleton instance
    _instance: "Context | None" = None

    # debug flag
    debug: bool = DEFAULT_DEBUG

    dry_run: bool = False

    # forever mode: how much to sleep in-between runs
    sleep_interval: float = DEFAULT_SLEEP_INTERVAL

    is_mac: bool = platform.system() == "Darwin"
    is_win: bool = platform.system() == "Windows"
    is_nix: bool = platform.system() not in ("Darwin", "Windows")

    catalog_url: str = CATALOG_URL
    download_url: str = DOWNLOAD_URL
    qbt: qbittorrentapi.Client

    # filters
    filenames: set[str] = field(default_factory=lambda: DEFAULT_FILTER_FILENAMES)
    languages: set[str] = field(default_factory=lambda: DEFAULT_FILTER_LANGUAGES)
    categories: set[str] = field(default_factory=lambda: DEFAULT_FILTER_CATEGORIES)
    flavours: set[str] = field(default_factory=lambda: DEFAULT_FILTER_FLAVOURS)
    tags: set[str] = field(default_factory=lambda: DEFAULT_FILTER_TAGS)
    authors: set[str] = field(default_factory=lambda: DEFAULT_FILTER_AUTHORS)
    publishers: set[str] = field(default_factory=lambda: DEFAULT_FILTER_PUBLISHERS)
    filesizes: SizeRange = field(default_factory=lambda: DEFAULT_FILTER_FILESIZES)

    # general options
    max_storage: int = DEFAULT_MAX_STORAGE
    keep_for: float = DEFAULT_KEEP_DURATION
    all_good: bool = SEED_WHOLE_CATALOG

    logger: logging.Logger = logging.getLogger(NAME)  # noqa: RUF009
    max_direct_online_resource_payload_size: int = 2048

    @classmethod
    def setup(cls, **kwargs: Any):
        if cls._instance:
            raise OSError("Already inited Context")
        cls._instance = cls(**kwargs)
        cls.setup_logger()

    @classmethod
    def setup_logger(cls):
        debug = cls._instance.debug if cls._instance else cls.debug
        if cls._instance:
            cls._instance.logger.setLevel(
                logging.DEBUG if debug else logging.INFO
            )
        else:
            cls.logger.setLevel(
                logging.DEBUG if debug else logging.INFO
            )
        logging.basicConfig(
            level=logging.DEBUG if debug else logging.INFO,
            format="%(asctime)s %(levelname)s | %(message)s",
        )

    @classmethod
    def get(cls) -> "Context":
        if not cls._instance:
            raise OSError("Uninitialized context")  # pragma: no cover
        return cls._instance

    @staticmethod
    def get_cache_path(fname: str) -> Path:
        """Path to save/read cache from/to"""
        xdg_cache_home = os.getenv("XDG_CACHE_HOME")
        # favor this env on any platform
        if xdg_cache_home:
            return Path(xdg_cache_home) / fname
        if Context.is_mac:
            return Path.home() / "Library" / "Caches" / NAME / fname
        if Context.is_win:
            return Path(os.getenv("APPDATA", "C:")) / NAME / fname
        return Path.home() / ".config" / NAME / fname

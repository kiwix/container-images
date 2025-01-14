import logging
import os
import platform
from dataclasses import dataclass, field
from typing import Any, Self
from urllib.parse import ParseResult, urlparse

import humanfriendly
import qbittorrentapi

NAME = "kiwix-seeder"  # must be filesystem-friendly (technical)
CLI_NAME = "kiwix-seeder"
HUMAN_NAME = "Kiwix Seeder"
QBT_CAT_NAME = "kiwix-seeder"  # name of category to group our torrents in

CATALOG_URL = os.getenv("CATALOG_URL", "https://library.kiwix.org/catalog/v2")
DOWNLOAD_URL = os.getenv("CATALOG_URL", "https://download.kiwix.org")
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

DEFAULT_DEBUG: bool = bool(os.getenv("DEBUG"))


# avoid debug-level logs of 3rd party deps
for module in ("urllib3", "qbittorrentapi.request"):
    logging.getLogger(module).setLevel(logging.INFO)


def format_size(value: int) -> str:
    """human friendly representation of size (in binary form)"""
    return humanfriendly.format_size(value, binary=True)


@dataclass(kw_only=True)
class QbtConnection:
    username: str | None
    password: str | None
    host: str
    port: int

    @classmethod
    def using(cls, string: str) -> Self:
        uri = urlparse(string)
        if uri.scheme != "qsl":
            raise ValueError(f"Malformed qbt:// URI: {string}")
        return cls(
            username=uri.username,
            password=uri.password,
            host=uri.hostname or "localhost",
            port=uri.port or 80,
        )

    def __str__(self) -> str:
        return ParseResult(
            scheme="qsl",
            netloc=f"{self.username or ''}"
            f"{':' if self.password else ''}{self.password or ''}"
            f"@{self.host}:{self.port}",
            path="",
            params="",
            query="",
            fragment="",
        ).geturl()


DEFAULT_QBT_CONN = str(
    QbtConnection.using(str(os.getenv("QBT_URI")))
    if os.getenv("QBT_URI")
    else QbtConnection(
        username=DEFAULT_QBT_USERNAME,
        password=DEFAULT_QBT_PASSWORD,
        host=DEFAULT_QBT_HOST,
        port=DEFAULT_QBT_PORT,
    )
)


@dataclass(kw_only=True)
class SizeRange:
    minimum: int = -1
    maximum: int = -1

    def is_valid(self) -> bool:
        if self.minimum == self.maximum == -1:
            return True
        # maximum is either not set or positive
        if self.maximum != -1:
            return max(self.maximum, 0) >= max(self.minimum, 0)
        return True

    def is_above_min(self, value: int) -> bool:
        return value >= max(self.minimum, 0)

    def is_below_max(self, value: int) -> bool:
        if self.maximum == -1:
            return True
        return value <= self.maximum

    def match(self, value: int) -> bool:
        # not valid, not matching.
        if not self.is_valid():
            return False
        # no bound, always OK
        if self.minimum == self.maximum == -1:
            return True
        return self.is_above_min(value) and self.is_below_max(value)

    def __str__(self) -> str:
        if not self.is_valid():
            return f"Invalid range: min={self.minimum}, max={self.maximum}"
        if self.minimum == self.maximum == -1:
            return "all"
        if self.minimum == self.maximum:
            return f"exactly {format_size(self.maximum)}"
        if self.minimum == -1:
            return f"below {format_size(self.maximum)}"
        if self.maximum == -1:
            return f"above {format_size(self.minimum)}"
        return f"between {format_size(self.minimum)} and {format_size(self.maximum)}"


@dataclass(kw_only=True)
class Context:

    # singleton instance
    _instance: "Context | None" = None

    # debug flag
    debug: bool = DEFAULT_DEBUG

    run_forever: bool = False
    sleep_interval: float = DEFAULT_KEEP_DURATION

    is_mac: bool = platform.system() == "Darwin"
    is_win: bool = platform.system() == "Windows"
    is_nix: bool = platform.system() not in ("Darwin", "Windows")

    catalog_url: str = CATALOG_URL
    download_url: str = DOWNLOAD_URL
    qbt: qbittorrentapi.Client

    filenames: set[str] = field(default_factory=set)
    languages: set[str] = field(default_factory=set)
    categories: set[str] = field(default_factory=set)
    flavours: set[str] = field(default_factory=set)
    tags: set[str] = field(default_factory=set)
    authors: set[str] = field(default_factory=set)
    publishers: set[str] = field(default_factory=set)
    filesizes: SizeRange = field(default_factory=SizeRange)
    max_storage: int = DEFAULT_MAX_STORAGE
    keep_for: float = DEFAULT_KEEP_DURATION
    all_good: bool = False

    logger: logging.Logger = logging.getLogger(NAME)  # noqa: RUF009
    max_direct_online_resource_payload_size: int = 2048

    @classmethod
    def setup(cls, **kwargs: Any):
        if cls._instance:
            raise OSError("Already inited Context")
        cls._instance = cls(**kwargs)
        cls._instance.logger.setLevel(
            logging.DEBUG if cls._instance.debug else logging.INFO
        )
        logging.basicConfig(
            level=logging.DEBUG if cls._instance.debug else logging.INFO,
            format="%(asctime)s %(levelname)s | %(message)s",
        )

    @classmethod
    def get(cls) -> "Context":
        if not cls._instance:
            raise OSError("Uninitialized context")  # pragma: no cover
        return cls._instance

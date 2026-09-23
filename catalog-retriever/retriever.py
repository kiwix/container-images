import datetime
import logging
import os
import re
import sys
import tempfile
import time
import urllib.parse
from pathlib import Path
from typing import Any, NamedTuple, Self, TypedDict

import requests
import requests.adapters
import unidecode
import xxhash
from humanfriendly import format_size
from oauthlib.oauth2 import BackendApplicationClient
from requests import PreparedRequest
from requests.adapters import HTTPAdapter
from requests.auth import HTTPBasicAuth
from requests_oauthlib import OAuth2Session

DEBUG: bool = bool(os.getenv("DEBUG", ""))
USER_AGENT: str = os.getenv("USER_AGENT", "kiwix-catalog-retriever/1.0")

SAVE_TO: Path = Path(os.getenv("SAVE_TO", "/data/catalog.xml")).expanduser().resolve()
CMS_COLLECTION_ID: str = os.getenv("CMS_COLLECTION_ID", "-")

CMS_API_URL: str = os.getenv("CMS_API_URL", "-")
REFRESH_EVERY_SECONDS: int = int(os.getenv("REFRESH_EVERY_SECONDS", "60"))

# CATALOG-ONLY OPTS
# value is added as prefix in front of the folder/fname from CMS
ADD_BOOK_PATH_TO_XML: str | None = os.getenv("ADD_BOOK_PATH_TO_XML", None)

# VARNISH/PURE OPTS
PURGE_VARNISH_URL: str = os.getenv("PURGE_VARNISH_URL", "")
KIWIX_SERVE_RELOAD_DELAY: int = int(os.getenv("KIWIX_SERVE_RELOAD_DELAY", "10"))
VARNISH_PURGE_HTTP_TIMEOUT: int = int(os.getenv("VARNISH_PURGE_HTTP_TIMEOUT", "10"))

USE_OAUTH: bool = bool(os.getenv("USE_OAUTH", ""))
OAUTH_AUDIENCE: str = os.getenv("OAUTH_AUDIENCE", "-")
OAUTH_CLIENT_ID: str = os.getenv("OAUTH_CLIENT_ID", "-")
OAUTH_CLIENT_SECRET: str = os.getenv("OAUTH_CLIENT_SECRET", "-")
OAUTH_TOKEN_RENEWAL_WINDOW: datetime.timedelta = datetime.timedelta(minutes=1)

logging.basicConfig(level=logging.DEBUG if DEBUG else logging.INFO)
logger = logging.getLogger("retriever")


type BookLineDigest = str
type BookId = str
type BookAlias = str
type BookCore = str
type UpdatedZim = tuple[BookId, BookCore]


class OAuth2Token(TypedDict):
    access_token: str
    expires_in: int
    scope: str
    token_type: str
    expires_at: int


class KiwixLoginOAuthAdapter(HTTPAdapter):
    def _init_token(self):
        """setup our instance vars (hack to not override __init__)"""
        if not hasattr(self, "_access_token"):
            self._access_token: str = ""
            self._token_expires_on: datetime.datetime = datetime.datetime.fromtimestamp(
                0, tz=datetime.UTC
            )

    def check_token(self) -> None:
        """checks if token expired and renews if not"""
        self._init_token()

        if not self._access_token or datetime.datetime.now(tz=datetime.UTC) >= (
            self.token_expires_on - OAUTH_TOKEN_RENEWAL_WINDOW
        ):
            self.fetch_token()
        if not self._access_token:
            raise OSError("Failed to fetch access token.")

    def fetch_token(self) -> None:
        """Authenticates via OAuth and stores received bearer token"""
        client = BackendApplicationClient(client_id=OAUTH_CLIENT_ID)
        oauth_session = OAuth2Session(client=client)
        oauth_session.headers["User-Agent"] = USER_AGENT
        payload: OAuth2Token = oauth_session.fetch_token(  # type: ignore
            token_url="https://ory.login.kiwix.org/oauth2/token",
            client_id=OAUTH_CLIENT_ID,
            client_secret=OAUTH_CLIENT_SECRET,
            auth=HTTPBasicAuth(OAUTH_CLIENT_ID, OAUTH_CLIENT_SECRET),
            audience=OAUTH_AUDIENCE,
        )
        self._access_token = payload["access_token"]
        self._token_expires_on = datetime.datetime.fromtimestamp(
            timestamp=payload["expires_at"], tz=datetime.UTC
        )

    @property
    def access_token(self) -> str:
        """actual access token, refreshed first if expired"""
        self.check_token()
        return self._access_token

    @property
    def token_expires_on(self) -> datetime.datetime:
        """token expiration"""
        return self._token_expires_on

    def add_headers(self, request: PreparedRequest, **kwargs: Any) -> None:
        """Adds Authorization header (called by requests itself)"""
        self._init_token()
        request.headers["Authorization"] = f"Bearer {self.access_token}"


session: requests.Session = requests.Session()
session.headers.update({"User-Agent": USER_AGENT})
cms_adapter = KiwixLoginOAuthAdapter() if USE_OAUTH else HTTPAdapter()
session.mount(CMS_API_URL, cms_adapter)


class CatalogEntry(NamedTuple):
    core: BookCore
    alias: BookAlias
    digest: BookLineDigest

    @classmethod
    def empty(cls) -> Self:
        return cls("", "", "")


class Catalog:
    entries: dict[BookId, CatalogEntry]

    def __init__(self) -> None:
        self.entries = {}


def get_catalog_url() -> str:
    path = (
        f"collections/{CMS_COLLECTION_ID}"
        if CMS_COLLECTION_ID != "staging"
        else CMS_COLLECTION_ID
    )
    return f"{CMS_API_URL}/{path}/catalog.xml"


def save_data(data: bytes, target: Path) -> bool:
    """whether data was saved correctly"""
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            prefix="catalog_", suffix=".xml", dir=target.parent
        ) as fh:
            src = Path(fh.name)
            src.write_bytes(data)
            src.chmod(0o644)
            try:
                src.rename(target)
            except Exception as exc:
                logger.error(
                    f"Failed to move temp file ({src}) to final path ({target}): {exc!s}"
                )
                logger.debug(exc, exc_info=True)
                return False
    except Exception as exc:
        logger.error(f"Failed to record catalog data to disk: {exc!s}")
        logger.debug(exc, exc_info=True)
        return False

    return True


def to_core(fpath: Path) -> str:
    """human identifier from ZIM filename"""
    return fpath.stem


def to_human_id(fpath: Path) -> str:
    """libkiwix-compat human ID (used in path-prefix) for a ZIM file"""
    return unidecode.unidecode(fpath.stem.replace(" ", "_").replace("+", "plus"))


def without_period(text: str) -> str:
    """text or filename without its ending _YYYY-MM period suffix"""
    return re.sub(r"_\d{4}-\d{2}$", "", re.sub(r"\.zim$", "", text))


def to_human_alias(fpath: Path) -> str:
    """libkiwix --nodatealias equivalent from ZIM filename"""
    return without_period(to_human_id(fpath))


def get_url_from(line: bytes) -> str:
    """ZIM url from a raw catalog line

    assumes line end with `url="xxx"/>` or `url="xxx" flavour="yyy"/>`"""
    return (
        line.removesuffix(b"/>")
        .split(b'" flavour="', 1)[0][line.index(b'" url="https') + 7 :]
        .rsplit(b'"', 1)[0]
        .removesuffix(b".meta4")
        .decode("UTF-8")
    )


def get_core_alias_from(line: bytes) -> tuple[BookAlias, BookCore]:
    """BookAlias and BookCore from a line of catalog xml data"""

    url = Path(get_url_from(line))
    return to_human_alias(url), to_core(url)


def parse_catalog_for_updates(payload: bytes) -> dict[BookAlias, UpdatedZim]:
    """dict of book ident info for all books that changed or were removed"""

    logger.info("[PARSE] reading new catalog")
    # make a copy of current (now previous) catalog so we can compare which changed
    previous_entries = Catalog.entries.copy()
    # reset the catalog store (we'll rebuild from scratch)
    Catalog.entries = {}

    updated_zims: dict[BookAlias, UpdatedZim] = {}
    for line in payload.split(b"\n"):
        if not line.startswith(b"  <book "):
            continue

        # retrieve the info we need, leveraging the static xml format
        # and without actual parsing
        book_id: BookId = line[12:48].decode("ASCII")  # fmt is `  <book id="<md5>" xxx`
        alias, core = get_core_alias_from(line)
        digest: BookLineDigest = xxhash.xxh3_64_hexdigest(line)

        # add entry to the catalog
        Catalog.entries[book_id] = CatalogEntry(core=core, alias=alias, digest=digest)

        # add to update list of line digest is different
        previous_digest = previous_entries.get(book_id, CatalogEntry.empty()).digest
        if previous_digest != digest:
            is_new = previous_digest == ""
            logger.debug(
                "> {alias} ({book_id}) is different" + (" (new)" if is_new else "")
            )
            updated_zims[alias] = (book_id, core)

    del previous_entries
    return updated_zims


def purge_vanish(data: bytes, varnish_url: str):
    logger.info(f"Purging varnish in {KIWIX_SERVE_RELOAD_DELAY}s {varnish_url}")
    sleep_for(KIWIX_SERVE_RELOAD_DELAY)
    updated_zims = parse_catalog_for_updates(data)
    logger.info(f"[PARSE] Found {len(updated_zims)} updates…")
    pure_varnish_library(varnish_url=varnish_url)
    purge_varnish_books(varnish_url=varnish_url, updated_zims=updated_zims)


def pure_varnish_library(varnish_url: str):
    logger.info(f"[PURGE] Requesting Library purge from {varnish_url}")
    resp = session.request(
        method="PURGE",
        url=varnish_url,
        headers={"X-Purge-Type": "library"},
        timeout=VARNISH_PURGE_HTTP_TIMEOUT,
    )
    if not resp.ok:
        logger.error(f"[PURGE] > HTTP {resp.status_code}/{resp.reason}")


def purge_varnish_books(varnish_url: str, updated_zims: dict[str, tuple[str, str]]):
    logger.info("[PURGE] Requesting Books purge for")
    for book_alias, (book_id, book_core) in updated_zims.items():
        logger.debug(f"[PURGE] > {book_alias} / {book_core} / {book_id}")
        resp = session.request(
            method="PURGE",
            url=varnish_url,
            headers={
                "X-Purge-Type": "book",
                "X-Book-Id": book_id,
                "X-Book-Name": book_core,
                # only account for new-style book name fmt (yolo)
                "X-Book-Name-Nodate": book_alias,
            },
            timeout=VARNISH_PURGE_HTTP_TIMEOUT,
        )
        if not resp.ok:
            logger.error(f"[PURGE] >> HTTP {resp.status_code}/{resp.reason}")


def get_data(url: str, add_path: str | None = None) -> tuple[bytes, str]:
    """full catalog data"""
    try:
        resp = session.get(
            url,
            allow_redirects=False,
            params={"path_prefix": add_path},
        )
        resp.raise_for_status()
    except Exception as exc:
        logger.error(f"Failed to retrieve catalog from {url}: {exc!s}")
        logger.debug(exc, exc_info=True)
        raise
    return resp.content, resp.headers.get("etag", "")


def has_update(url: str, etag: str) -> bool:
    """whether data should be downloaded again"""
    try:
        resp = session.head(url)
        resp.raise_for_status()
        new_etag = resp.headers.get("etag", "")
    except Exception as exc:
        logger.error(f"Failed to retrieve catalog from {url}: {exc!s}")
        logger.debug(exc, exc_info=True)
        return True
    return bool(new_etag) and new_etag != etag


def sleep_for(seconds: int):
    """sleep via 1s interval so process can be interrupted"""
    elapsed = 0
    while elapsed < seconds:
        time.sleep(1)
        elapsed += 1


def main() -> int:
    url = get_catalog_url()
    url_p = urllib.parse.urlparse(url)
    logger.info(
        f"starting catalog-retriever for “{CMS_COLLECTION_ID}” from {url_p.netloc}"
    )

    etag = ""  # start empty so we always re-fectch on start

    while True:
        try:
            if bool(etag) and not has_update(url, etag=etag):
                logger.debug(f"No update {etag=}")
                continue
            payload, etag = get_data(url=url, add_path=ADD_BOOK_PATH_TO_XML)
        except Exception as exc:
            logger.error(f"Failed to retrieve catalog from {url}: {exc!s}")
            logger.debug(exc, exc_info=True)
            continue
        else:
            save_data(data=payload, target=SAVE_TO)
            logger.info(f"Updated catalog with {etag=} ({format_size(len(payload))})")
            if PURGE_VARNISH_URL:
                purge_vanish(data=payload, varnish_url=PURGE_VARNISH_URL)
        finally:
            sleep_for(REFRESH_EVERY_SECONDS)

    return 0


def entrypoint() -> int:
    return main()


if __name__ == "__main__":
    sys.exit(entrypoint())

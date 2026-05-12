import logging
import os
import sys
import tempfile
import time
import urllib.parse
from pathlib import Path

import requests
from humanfriendly import format_size

DEBUG = bool(os.getenv("DEBUG", ""))

SAVE_TO = Path(os.getenv("SAVE_TO", "/data/catalog.xml")).expanduser().resolve()
CMS_COLLECTION_ID = os.getenv("CMS_COLLECTION_ID", "-")

CMS_API_URL = os.getenv("CMS_API_URL", "-")
REFRESH_EVERY_SECONDS = int(os.getenv("REFRESH_EVERY_SECONDS", "60"))

logging.basicConfig(level=logging.DEBUG if DEBUG else logging.INFO)
logger = logging.getLogger("retriever")


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


def get_data(url: str) -> tuple[bytes, str]:
    """full catalog data"""
    try:
        resp = requests.get(url, allow_redirects=False)
        resp.raise_for_status()
    except Exception as exc:
        logger.error(f"Failed to retrieve catalog from {url}: {exc!s}")
        logger.debug(exc, exc_info=True)
        raise exc
    return resp.content, resp.headers.get("etag", "")


def has_update(url: str, etag: str) -> bool:
    """whether data should be downloaded again"""
    try:
        resp = requests.head(url)
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
            payload, etag = get_data(url=url)
        except Exception as exc:
            logger.error(f"Failed to retrieve catalog from {url}: {exc!s}")
            logger.debug(exc, exc_info=True)
            continue
        else:
            save_data(data=payload, target=SAVE_TO)
            logger.info(f"Updated catalog with {etag=} ({format_size(len(payload))})")
        finally:
            sleep_for(REFRESH_EVERY_SECONDS)

    return 0


def entrypoint() -> int:
    return main()


if __name__ == "__main__":
    sys.exit(entrypoint())

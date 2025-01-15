import datetime
import time
from dataclasses import dataclass
from typing import Self

import qbittorrentapi

from kiwixseeder.context import QBT_CAT_NAME, Context
from kiwixseeder.download import get_btih_from_url
from kiwixseeder.library import Book
from kiwixseeder.utils import format_size

context = Context.get()
client = context.qbt
logger = context.logger


@dataclass(kw_only=True)
class TorrentInfo:
    """Custom backend-agnostic torrent info"""

    btih: str
    filename: str
    added_on: datetime.datetime
    size: int

    @classmethod
    def from_torrentdictionary(cls, tdict: qbittorrentapi.TorrentDictionary) -> Self:
        return cls(
            btih=tdict.properties.hash,
            filename=tdict.properties.name,
            added_on=datetime.datetime.fromtimestamp(
                tdict.properties.addition_date, tz=datetime.UTC
            ),
            size=tdict.properties.total_size,
        )

    def __str__(self) -> str:
        return (
            f"{self.filename} @ {self.btih} "  # noqa: RUF001
            f"({format_size(self.size)})"
        )


class TorrentManager:

    def __init__(self) -> None:
        # maps {ident: str} to {btih: str}
        self.btihs: dict[str, str] = {}

    def is_connected(self) -> tuple[bool, str | Exception]:
        """whether qbittorrent is reachable and either version or exception"""
        try:
            return True, client.app_version()
        except Exception as exc:
            return False, exc

    def setup(self):
        # ensure we have our category
        if QBT_CAT_NAME not in client.torrent_categories.categories:
            client.torrent_categories.create_category(name=QBT_CAT_NAME)

    def reload(self):
        """read torrents list from qbittorrent"""
        self.btihs.clear()
        for torrent in client.torrents.info(category=QBT_CAT_NAME):
            self.btihs[torrent.properties.hash] = torrent.properties.name

    @property
    def nb_torrents(self) -> int:
        return len(self.btihs)

    def add(self, book: Book) -> bool:
        btih = self.add_url(url=book.torrent_url, btih=book.btih)
        if not btih:
            return False
        if book.btih != btih:
            book.btih = btih
        return True

    def add_url(self, url: str, btih: str | None) -> str:
        # upload_limit
        # download_limit
        # save_path
        # ratio_limit
        # seeding_time_limit
        # download_path
        try:
            btih = btih or get_btih_from_url(url)
            if client.torrents.add(
                urls=url, category=QBT_CAT_NAME
            ) == "Ok." and self.get_or_none(btih, with_patience=True):
                return btih
            raise OSError(f"Failed to add torrent for {url}")
        finally:
            self.reload()

    def get(self, ident: str) -> TorrentInfo:
        """Torrent dict from its hash"""
        return TorrentInfo.from_torrentdictionary(
            client.torrents.info(torrent_hashes=ident)[0]
        )

    def get_or_none(
        self, ident: str, *, with_patience: bool = False
    ) -> TorrentInfo | None:
        """Torrent dict from its hash or None"""
        if with_patience:
            attempts = 100
            duration = 0.1
        else:
            attempts = 1
            duration = 0
        while attempts:
            attempts -= 1
            try:
                return self.get(ident)
            except IndexError:
                time.sleep(duration)
                continue
        return None

    def remove(self, ident: str) -> bool:
        """Remove a single torrent (if present) via its hash"""
        try:
            client.torrents.delete(torrent_hashes=ident, delete_files=True)
        finally:
            self.reload()
        return ident not in self.btihs

    @property
    def total_size(self) -> int:
        """total size of our torrents"""
        self.reload()
        return sum(self.get(btih).size for btih in self.btihs)

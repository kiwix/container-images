import datetime
import fnmatch

from kiwixseeder.context import (
    QBT_CAT_NAME,
    RC_INSUFFICIENT_STORAGE,
    RC_NOFILTER,
    Context,
)
from kiwixseeder.library import Book, Catalog, query_etag, write_etag_to_cache
from kiwixseeder.qbittorrent import TorrentManager
from kiwixseeder.utils import format_size

context = Context.get()
logger = context.logger


class Runner:

    def __init__(self) -> None:
        self.exit_requested: bool = False
        self.now = datetime.datetime.now(datetime.UTC)
        self.manager: TorrentManager = TorrentManager()
        self.catalog: Catalog = Catalog()
        self.books: list[Book] = []
        self.banner: str = "[dry-mode] " if context.dry_run else ""

    def stop(self):
        self.exit_requested = True

    def run(self) -> int:
        stop_after_filters: bool = False

        self.display_filters()
        try:
            self.connect_to_backend()
        except Exception as exc:
            if context.dry_run:
                logger.warning(
                    f"{self.banner}Unable to connect to qBittorrent. "
                    "We'll will stop after filters"
                )
                stop_after_filters = True
            else:
                raise exc

        if self.fetch_catalog():
            logger.info("Catalog has not changed since last run, exiting.")
            return 0
        catalog_size = self.catalog.nb_books
        self.reduce_catalog()

        # make sure it's not an accidental no-param call
        books_size = sum(book.size for book in self.books)
        if len(self.books) == catalog_size and not context.all_good:
            logger.warning(
                f"{self.banner}You requesting seeding {len(self.books)} torrents "
                f"accounting for {format_size(books_size)}. "
            )
            if (
                not context.dry_run
                and input("Do you want to continue? Y/[N] ").upper() != "Y"
            ):
                logger.info("OK, exiting.")
                return RC_NOFILTER

        if stop_after_filters:
            return 0

        # read existing torrents from qbt
        self.manager.reload()
        logger.info(
            f"{self.banner}There are {self.manager.nb_torrents} torrents "
            f"in {QBT_CAT_NAME}"
        )
        for btih in self.manager.btihs:
            logger.debug(f"* {self.manager.get(btih)!s}")

        self.remove_outdated_torrents()
        self.reconcile_books_and_torrents()

        if self.ensure_storage():
            return RC_INSUFFICIENT_STORAGE

        self.add_books()

        logger.info(f"{QBT_CAT_NAME} has {self.manager.nb_torrents} torrents")
        return 0

    def display_filters(self):
        logger.info(f"{self.banner}Starting super-seeder with filters:")
        logger.info(f"Filenames: {', '.join(context.filenames) or 'all'}")
        logger.info(f"Languages: {', '.join(context.languages) or 'all'}")
        logger.info(f"Categories: {', '.join(context.categories) or 'all'}")
        logger.info(f"Flavours: {', '.join(context.flavours) or 'all'}")
        logger.info(f"Tags: {', '.join(context.tags) or 'all'}")
        logger.info(f"Authors: {', '.join(context.authors) or 'all'}")
        logger.info(f"Publishers: {', '.join(context.publishers) or 'all'}")
        logger.info(f"Size: {context.filesizes!s}")

        if not context.filesizes.is_valid():
            raise ValueError("Invalid filters combination: sizes")

    def connect_to_backend(self):
        logger.info("Checking qBittorrent connection…")
        succeeded, vers_or_exc = self.manager.is_connected()
        if not succeeded and isinstance(vers_or_exc, BaseException):
            raise OSError(
                f"Unable to connect to qBittorrent: {vers_or_exc!s}"
            ) from vers_or_exc
        logger.info(f"> Connected to qBittorrent {vers_or_exc} ; fetching data…")

        self.manager.setup()

    def fetch_catalog(self):
        logger.info("Fetching catalog…")
        etag = query_etag()
        # resources online is same as last time
        if etag and self.catalog.etag and etag == self.catalog.etag:
            return True
        self.catalog.ensure_fresh()
        if not context.dry_run:
            write_etag_to_cache(self.catalog.etag)
        logger.info(f"Catalog contains {self.catalog.nb_books} ZIMs")

    def reduce_catalog(self):
        # build books with our filters
        self.books = list(filter(self.matches, self.catalog.all_books))

        # drop catalog (we dont need any of it anymore)
        self.catalog.reset()

        logger.info(f"\033[0;32mFilters matches {len(self.books)} ZIMs\033[0m")
        if len(self.books) <= 15:  # noqa: PLR2004
            for book in self.books:
                logger.debug(f"* {book!s}")

    def remove_outdated_torrents(self):
        if not self.manager.btihs:
            return

        logger.info("Checking for existing torrents removal…")

        # reconciling existing torrents and books
        unselected_books = list(self.manager.btihs.keys())
        for book in self.books:
            btihs = [
                btih
                for btih, fname in self.manager.btihs.items()
                # having condition on name first is important and it allows
                # us to only compare on btih if name matches.
                # we cant direclty compare on btih as it would require getting the
                # btih of all books otherwise which is resource intensive as it
                # requires an HTTP GET for each
                if fname == book.filename and book.btih == btih
            ]
            if btihs:
                book.btih = btihs[0]
                unselected_books.remove(book.btih)

        # keep those that are within --keep duration
        keep_until = self.now - datetime.timedelta(seconds=context.keep_for)
        for btih in unselected_books:
            if self.manager.get(btih).added_on >= keep_until:
                unselected_books.remove(btih)

        if not len(unselected_books):
            logger.info("> None")
            return

        logger.info(
            f"{self.banner}Removing {len(unselected_books)} outdated torrents "
            "(not in catalog, over --keep)…"
        )
        for btih in unselected_books:
            logger.info(f"- {self.manager.get(btih)!s}")
            if context.dry_run:
                continue
            if not self.manager.remove(btih):
                logger.error(f"Failed to remove {btih}")

    def ensure_storage(self):
        torrents_size = self.manager.total_size
        books_size = sum(book.size for book in self.books)
        total_size = torrents_size + books_size
        logger.info(f"{self.banner}Checking overall storage needs:")
        logger.debug(f"- Existing torrents: {format_size(torrents_size)}")
        logger.debug(f"- Requested new torrents: {format_size(books_size)}")
        logger.info(
            f"- Total torrents: {format_size(total_size)} "
            f"{'>' if torrents_size > context.max_storage else '<='} "
            f"{format_size(context.max_storage)} (max storage)"
        )

        if total_size > context.max_storage:
            logger.error("Total size exceeds max-storage")
            return True

    def reconcile_books_and_torrents(self):
        logger.info(
            "Reconciling books and torrents (may require btih endpoint requests)"
        )
        self.books = [
            book for book in self.books if book.btih not in self.manager.btihs
        ]

    def add_books(self):
        logger.info(f"{self.banner}Adding {len(self.books)} torrents…")
        for num, book in enumerate(self.books):
            if context.dry_run:
                logger.info(f"{num}. Would add {book!s}")
                continue
            if self.manager.add(book):
                logger.info(f"{num}. Added {book!s}")
            else:
                logger.error(f"Failed to add {book!s}")

    def matches_filename(self, book: Book) -> bool:
        if not context.filenames:
            return True

        for pattern in context.filenames:
            if book.filepath.match(pattern):
                return True
        return False

    def matches_lang(self, book: Book) -> bool:
        if not context.languages:
            return True
        for lang_code in context.languages:
            if lang_code in book.lang_codes:
                return True
        return False

    def matches_category(self, book: Book) -> bool:
        if not context.categories:
            return True
        for category_pattern in context.categories:
            if fnmatch.fnmatch(book.category, category_pattern):
                return True
        return False

    def matches_flavour(self, book: Book) -> bool:
        if not context.flavours:
            return True
        for flavour in context.flavours:
            if flavour == book.flavour:
                return True
        return False

    def matches_tag(self, book: Book) -> bool:
        if not context.tags:
            return True
        for tag_pattern in context.tags:
            for tag in book.tags:
                if fnmatch.fnmatch(tag, tag_pattern):
                    return True
        return False

    def matches_author(self, book: Book) -> bool:
        if not context.authors:
            return True
        for author_pattern in context.authors:
            if fnmatch.fnmatch(book.author, author_pattern):
                return True
        return False

    def matches_publisher(self, book: Book) -> bool:
        if not context.publishers:
            return True
        for publisher_pattern in context.publishers:
            if fnmatch.fnmatch(book.publisher, publisher_pattern):
                return True
        return False

    def matches_size(self, book: Book) -> bool:
        return context.filesizes.match(book.size)

    def matches(self, book: Book) -> bool:
        for value in (
            "filename",
            "lang",
            "category",
            "flavour",
            "tag",
            "author",
            "publisher",
            "size",
        ):
            if not getattr(self, f"matches_{value}")(book):
                return False
        return True

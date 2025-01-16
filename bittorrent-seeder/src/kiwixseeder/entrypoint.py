import argparse
import signal
import sys
from types import FrameType

import humanfriendly
import qbittorrentapi
from rich.markdown import (  # pyright: ignore [reportMissingImports]
    Markdown,  # pyright: ignore [reportUnknownVariableType]
)
from rich_argparse import (  # pyright: ignore [reportMissingImports]
    RichHelpFormatter,  # pyright: ignore [reportUnknownVariableType]
)

from kiwixseeder.__about__ import __version__
from kiwixseeder.context import (
    CLI_NAME,
    DEFAULT_KEEP_DURATION,
    DEFAULT_MAX_STORAGE,
    DEFAULT_QBT_CONN,
    DEFAULT_SLEEP_INTERVAL,
    Context,
    QbtConnection,
    SizeRange,
)
from kiwixseeder.utils import format_duration, format_size

logger = Context.logger

epilog = """
---
## Keeping ZIMs

`--keep` allows you to keep seeding ZIMs after those drop out of the Catalog.
The Catalog only exposes the latest version of a *Title*. With many *Titles* being \
redone monthly.\n
The webseeds (HTTP mirrors) only keep at most 2 versions of a *Title*.
This option expects a

## Glob-patterns

- filename-patterns are absolute (root is `/`)
- root starts below zim folder (so `/zim` for instance)
- `**` means any directory tree
- `*` Matches any number of non-separator characters, including zero.
- `[seq]` Matches one character in seq.
- `[!seq]` Matches one character not in seq.

Sample requests:

- `wikipedia/*`: All in wikipedia folder
- `wikipedia_fr_*` All wikipedia with `fr` lang (See --lang as well)
- `*_maxi_*` All maxi ones
- `wikipedia_fr_all_nopic_*` specific

See https://docs.python.org/3/library/pathlib.html#pattern-language
"""


def prepare_context(raw_args: list[str]) -> None:
    parser = argparse.ArgumentParser(
        prog=CLI_NAME,
        description="Automates a qBitottorrent instance to seed "
        "all or part of the Kiwix Catalog",
        formatter_class=RichHelpFormatter,  # pyright: ignore [reportUnknownArgumentType]
        epilog=Markdown(
            epilog, style="argparse.text"
        ),  # pyright: ignore [reportUnknownArgumentType]
    )

    parser.add_argument(
        "--loop",
        dest="run_forever",
        help="Run forever sleeping, "
        f"executing every {format_duration(DEFAULT_SLEEP_INTERVAL)}",
        action="store_true",
    )

    parser.add_argument(
        "--qbt",
        dest="qbt_uri",
        help="qBittorrent connection string. "
        "Format: qbt://{user}:{password}@{host}:{port}. "
        "Can be set via QBT_URI or parts via QBT_USER, QBT_PASSWORD, "
        f"QBT_HOST and QBT_PORT. Defaults to {DEFAULT_QBT_CONN}",
        type=str,
        default=DEFAULT_QBT_CONN,
        required=False,
    )

    parser.add_argument(
        "--version",
        help="Display scraper version and exit",
        action="version",
        version=__version__,
    )

    parser.add_argument(
        "--debug",
        dest="debug",
        help="Enable debug-level logs",
        default=Context.debug,
        action="store_true",
    )

    parser.add_argument(
        "--all-good",
        dest="all_good",
        action="store_true",
        help="Continue even if your filters "
        "didnt filter anything out (thousands of torrents)",
        required=False,
    )

    parser.add_argument(
        "--filename",
        dest="filenames",
        action="append",
        help="Only seed ZIMs matching this folder/filename pattern.\n"
        "Can be used multiple times.\n"
        "glob-pattern accepted.",
        type=str,
        default=[],
        required=False,
    )

    parser.add_argument(
        "--lang",
        dest="languages",
        action="append",
        help="Only seed ZIMs for this ISO-639-3 language code.\n"
        "Can be used multiple times.",
        type=str,
        default=[],
        required=False,
    )

    parser.add_argument(
        "--category",
        dest="categories",
        action="append",
        help="Only seed ZIMs in this category.\nCan be used multiple times."
        "\nglob-pattern accepted.",
        type=str,
        default=[],
        required=False,
    )

    parser.add_argument(
        "--flavour",
        dest="flavours",
        action="append",
        choices=["nodet", "mini", "nopic", "maxi"],
        help="Only seed ZIMs of this flavour.\nCan be used multiple times."
        "\nglob-pattern accepted.",
        type=str,
        default=[],
        required=False,
    )

    parser.add_argument(
        "--tags",
        dest="tags",
        action="append",
        help="Only seed ZIMs with this tag.\nCan be used multiple times."
        "\nglob-pattern accepted.",
        type=str,
        default=[],
        required=False,
    )

    parser.add_argument(
        "--author",
        dest="authors",
        action="append",
        help="Only seed ZIMs created by this one.\nCan be used multiple times."
        "\nglob-pattern accepted.",
        type=str,
        default=[],
        required=False,
    )

    parser.add_argument(
        "--publisher",
        dest="publishers",
        action="append",
        help="Only seed ZIMs published by this one.\nCan be used multiple times."
        "\nglob-pattern accepted.",
        type=str,
        default=[],
        required=False,
    )

    parser.add_argument(
        "--min-file-size",
        dest="min_size",
        help="Only seed ZIMs at least this size. Input is parsed for suffix",
        type=str,
        default=None,
        required=False,
    )

    parser.add_argument(
        "--max-file-size",
        dest="max_size",
        help="Only seed ZIMs at most this size. Input is parsed for suffix",
        type=str,
        default=None,
        required=False,
    )

    parser.add_argument(
        "--max-storage",
        dest="max_storage",
        help="Overall seeder storage. "
        "Removes older torrents if new ones require additional disk space. "
        f"Defaults to {format_size(DEFAULT_MAX_STORAGE)}",
        type=str,
        default=format_size(DEFAULT_MAX_STORAGE),
        required=False,
    )

    parser.add_argument(
        "--keep",
        dest="keep_for",
        help="Duration for which to keep an already-added torrent "
        "once it dropped out of the Catalog. Duration is computed from added date. "
        "Use duration prefixes (d for days, w for weeks, y for years). "
        f"Defaults to {format_duration(DEFAULT_KEEP_DURATION)}",
        type=str,
        default=format_duration(DEFAULT_KEEP_DURATION),
        required=False,
    )

    args = parser.parse_args(raw_args)

    # ignore unset values in order to not override Context defaults
    args_dict = {key: value for key, value in args._get_kwargs() if value}

    # de-dup list of strings and cast to set
    for key in ("folder_prefixes", "categories", "tags", "scrapers"):
        if key in args_dict:
            args_dict[key] = set(args_dict[key])

    # size-range
    min_size: int = (
        -1 if args.min_size is None else humanfriendly.parse_size(args.min_size)
    )
    max_size: int = (
        -1 if args.max_size is None else humanfriendly.parse_size(args.max_size)
    )
    args_dict.update({"filesizes": SizeRange(minimum=min_size, maximum=max_size)})
    for key in ("min_size", "max_size"):
        if key in args_dict:
            del args_dict[key]

    # storage
    args_dict["max_storage"] = humanfriendly.parse_size(args_dict["max_storage"])

    # keep duration
    args_dict["keep_for"] = humanfriendly.parse_timespan(args_dict["keep_for"])

    # qbittorrent client
    conn = QbtConnection.using(args_dict["qbt_uri"])
    args_dict["qbt"] = qbittorrentapi.Client(
        host=conn.host,
        port=conn.port,
        username=conn.username,
        password=conn.password,
    )
    del args_dict["qbt_uri"]

    Context.setup(**args_dict)


def main() -> int:
    try:
        prepare_context(sys.argv[1:])
        # late import as to have an initialized Context
        from kiwixseeder.runner import Runner

        runner = Runner()

        def exit_gracefully(signum: int, frame: FrameType | None):  # noqa: ARG001
            logger.info(f"Received {signal.Signals(signum).name}/{signum}. Exiting")
            runner.stop()

        signal.signal(signal.SIGTERM, exit_gracefully)
        signal.signal(signal.SIGINT, exit_gracefully)
        signal.signal(signal.SIGQUIT, exit_gracefully)

        return runner.run()
    except Exception as exc:
        logger.error(f"General failure: {exc!s}")
        logger.exception(exc)
        return 1


def entrypoint():
    sys.exit(main())

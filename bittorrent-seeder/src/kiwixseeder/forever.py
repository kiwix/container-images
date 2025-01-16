""" forever running assistant to kiwix-seeder

Provides a long-living process for Docker usage (as CMD) that periodically
launches kiwix-seeder.

Entirely driven by ENV (DEBUG, SLEEP_INTERVAL), it launches the regular kiwix-seeder
as a subprocess to prevent any failure in it from breaking the loop"""

import signal
import subprocess
import sys
import time
from types import FrameType

from kiwixseeder.context import RC_INSUFFICIENT_STORAGE, RC_NOFILTER, Context
from kiwixseeder.utils import format_duration

Context.setup_logger()
logger = Context.logger


def main(args: list[str]) -> int:
    logger.info("[forever] Starting kiwix-seeder runner")

    exit_requested: bool = False

    def exit_gracefully(signum: int, frame: FrameType | None):  # noqa: ARG001
        exit_requested = True  # noqa: F841 # pyright: ignore [reportUnusedVariable]
        logger.info(
            f"[forever] Received {signal.Signals(signum).name}/{signum}. Exiting"
        )
        sys.exit(-signum)

    signal.signal(signal.SIGTERM, exit_gracefully)
    signal.signal(signal.SIGINT, exit_gracefully)
    signal.signal(signal.SIGQUIT, exit_gracefully)

    while not exit_requested:
        ps = subprocess.run(["/usr/bin/env", "kiwix-seeder", *args], check=False)

        if ps.returncode in (RC_NOFILTER, RC_INSUFFICIENT_STORAGE):
            logger.info("OK, there's a config issue here. Exiting forever loop")
            return ps.returncode

        if ps.returncode < 0:
            return ps.returncode

        if exit_requested:
            return 0

        logger.info(f"Sleeping for {format_duration(Context.sleep_interval)}…")
        for _ in range(0, int(Context.sleep_interval)):
            time.sleep(1)
            if exit_requested:
                break

    return 0


def entrypoint():
    sys.exit(main(sys.argv[1:]))


if __name__ == "__main__":
    entrypoint()

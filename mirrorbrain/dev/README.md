# Development environment

This folder is not meant to reach production. It is a small stack based on docker compose to help developers
test changes locally before pushing them forward.

The stack deploys:
- our custom Mirrorbrain Docker image (web proxy)
- a PostgreSQL database

The stack contains configuration files which have been extracted from production and adapted to work locally.

This is hence not a 100% realistic setup, for instance redirect maps in Apache have been commented out for now.

## How to start the stack

First thing you will need is a MaxMind configuration file for GeoIP databases v2. This configuration file
should be retrieved from your MaxMind account, must be named `GeoIP.conf` and placed in `dev` folder.

Once this configuration file is in place, you can start the docker compose:
```bash
cd mirrorbrain/dev
docker compose -p mirrorbrain up -d
```

If it is the first time you start the stack, you must initialize DB schema and data. Password of `mirrorbrain` DB
user is `mirrorbrain`.

```
docker exec -it mb_web ./init_mirrorbrain_db_dev.sh
```

You must also update GeoIP database once in a while.

```
docker exec -it mb_web geoipupdate -v
```

## How to test mirror scanning and stuff like that

Mirrorbrain provides a helpfull utility named null-rsync which allows to mirror files locally in the Docker container
with sparse files (no content, no disk usage, only filename and attributes).

```bash
docker exec mb_web null-rsync master.download.kiwix.org::download.kiwix.org/ /var/www/download.kiwix.org/
```

Once this is done, you can run regular `mb` operations. For instance

```bash
docker exec mb_web mb scan -d nightly dotsrc.org
```

You can then check mirror is operating properly (note `X-Forwarded-For` header which is mandatory in our setup to pass end-user IP):
```
curl -H "X-Forwarded-For: 45.82.174.12" "http://localhost:8100/nightly/2023-10-26/kiwix-js-electron_i386_2023-10-26.deb?mirrorlist"
```
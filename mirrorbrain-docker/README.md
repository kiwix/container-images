# mirrorbrain-docker

This docker image allows to run the Apache HTTP daemon with the
Mirrorbrain module.

## Setup PostgreSQL database

Mirrorbrain works with PostgreSQL database engine, thus we must have a
reachable PostgreSQL daemon from mirrorbrain container. You can use
the official PostgreSQL docker image called `postgres`. The service we
must named "db" (matching with host name).

To initialize PostgreSQL database and exit:
`docker run -e INIT=1 -v /data/:/var/www  kiwix/mirrorbrain`

## Run Apache+Mirrorbrain HTTP service

To run the HTTP daemon on port 80 set environment variable `HTTPD` to
`1`:
`docker-compose run -e HTTPD=1 -v /data/:/var/www  kiwix/mirrorbrain`

## Run Mirrorbrain updates

Mirrorbrain database need to be kept updated periodicaly. To do each
hour, set environment variable `UPDATE_DB` (or `UPDATE_HASH`) to
`1`. Both are allowed.

To get a dedicated container, run that:
`docker-compose run -e UPDATE_DB=1 -v /data/:/var/www  kiwix/mirrorbrain`

To run a container which do everything (HTTP server + updates):
`docker-compose run -e HTTPD=1 -e UPDATE_HASH=1 -p 80:80 -v /data/:/var/www kiwix/mirrorbrain`

## Config files

- `config/mirrorbrain/mirrorbrain.conf` : config of Mirrorbrain
- `config/apache/httpd.conf`            : config of Apache httpd
- `config/apache/httpd-vhosts.conf`     : config of (your) Apache virtual host
- `sql/mirrors-postgresql.sql`          : SQL instructions to init mirror list

## See also

Mirrorbrain official site: http://mirrorbrain.org

## Author

Florent Kaisser <florent.pro@kaisser.name>

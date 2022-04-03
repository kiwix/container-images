## openZIM BitTorrent Super-seeder

The **openZIM BitTorrent Super-seeder** is a Docker image to easily
launch a BitTorrent super-seeder for all or part of the ZIM files
published at https://library.kiwix.org/zim.

It will share theses files which means concretly automatically:
* Download new ones
* Delete older one

### Principle

This Docker image works as a companion to the
[linuxserver/qbittorrent](https://hub.docker.com/r/linuxserver/qbittorrent)
Docker image. It is responsible the ZIM files served by
[qBittorrent](https://www.qbittorrent.org/) are kept in sync with
upstream https://library.kiwix.org/zim.

### Configure

The instance can be configurd via environnment variables:
* `DOWNLOAD_DIRECTORY_PATH`: directory path you want to have the ZIM files stored
* `DATA_PORT`: TCP & UDP ports for the data exchanges
* `ADMIN_PORT`: TCP admin port for qBittorrent

You can gather this conf in an environment file for example and run for example:
```bash
env $(env .env) docker-compose ...
```

### Run

The easiest solution to run the solution is to use
[docker-compose](https://docs.docker.com/compose/). Doing so, you will
be able with a simple command to start/stop the two Docker containers
(qBittorrent and the super-seeder companion).

To launch the service:
```bash
docker-compose up -d
```

To stop it:
```bash
docker-compose stop
```

### Advanced

Here are a bit of documentation for developers or users wanting to go
a bit more in depth with the solution.

#### qBittorrent

Refers to https://hub.docker.com/r/linuxserver/qbittorrent

#### Companion

To launch the companion:
```bash
docker run --network="host" --name=qbittorrent-zim-superseeder openzim/qbittorrent-zim-superseeder
```

To build the companion from the source code:
```bash
docker build -t openzim/qbittorrent-zim-superseeder .
```
openZIM BitTorrent Super-seeder
===============================

The **openZIM BitTorrent Super-seeder** is a Docker image to easily
launch a BitTorrent super-seeder for ZIM files published at
https://library.kiwix.org.

It not only will share theses files but will all download new ones and
delete older one automatically.

Principle
---------

This Docker image works as a companion to the
[linuxserver/qbittorrent](https://hub.docker.com/r/linuxserver/qbittorrent)
Docker image.

This Docker image only secure the ZIM files downloaded and server by
[qBittorrent](https://www.qbittorrent.org/) are synchronised with
https://library.kiwix.org.

Launch qBittorrent
------------------

Refers to https://hub.docker.com/r/linuxserver/qbittorrent

Launch companion
----------------

[![CodeFactor](https://www.codefactor.io/repository/github/kiwix/container-images/badge)](https://www.codefactor.io/repository/github/kiwix/container-images)

Create or update the containers
===============================

`docker-compose -p kiwix up -d`

Restart service
===============

`docker-compose -p kiwix restart <container-name>`

If you no set a container name, all service are restarted

Remove containers
=================

`docker-compose -p kiwix down`

List of available containers
=========================

- web
- reverse-proxy
- library
- mirrorbrain-web
- mirrorbrain-update
- mirrorbrain-db
- ftpd
- letsencrypt
- matomo-log-analytics_download

Secret
======

To start `matomo-log-analytics_download container`, we need to create `matomo-token.txt`  file with the token allow to send stats to matomo server
To start `library container`, we need to create `password-wiki.txt`  file with the password to access the wiki

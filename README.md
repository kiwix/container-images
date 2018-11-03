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

List of avaible container
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

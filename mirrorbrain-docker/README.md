# mirrorbrain-docker

This docker image allow to run the Mirrorbrain extension of Apache httpd.

## Init database

Mirrorbrain work with postgresql, thus we must have a reachable postgresql 
server from mirrorbrain container. We can use the official postgresql docker 
image. The service we must named "db" (matching with host name).

To init postgresql database we can run `init.sh` With docker compose :

` docker-compose run web init.sh`

## Run httpd server with Mirrorbrain

By default, httpd server listen on 82 port. To run the server on 80 port :

`docker-compose run -p 80:82 web `

## Create your image

We can personalize this image. For this, edit c./sql/mirrors-postgresql.sqlonfig files :

- config/mirrorbrain/mirrorbrain.conf : config file of mirrorbrain
- config/apache/httpd.conf : config file of Apache httpd
- config/apache/httpd-vhosts.conf : config your virtual host
- sql/mirrors-postgresql.sql : SQL instructions to init mirror list

## See also

Mirrorbrain official site : http://mirrorbrain.org

## Author

Florent Kaisser <florent.pro@kaisser.name>

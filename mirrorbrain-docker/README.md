# mirrorbrain-docker

This docker image allow to run the Mirrorbrain extension of Apache httpd.

## Init database

Mirrorbrain work with postgresql, thus we must have a reachable postgresql 
server from mirrorbrain container. We can use the official postgresql docker 
image. The service we must named "db" (matching with host name).

To init postgresql database :

` docker run -e INIT=1 -v /data/:/var/www  kiwix/mirrorbrain 

## Run with http server

To run the server on 80 port :

 `docker-compose run -e HTTPD=1 -v /data/:/var/www  kiwix/mirrorbrain 


## Run with cron
ex :
 `docker-compose run -e UPDATE_DB=1  -v /data/:/var/www  kiwix/mirrorbrain 

 `docker-compose run -e HTTPD=1 -e UPDATE_HASH=1  -p 80:80 -v /data/:/var/www  kiwix/mirrorbrain 


## Config files

- config/mirrorbrain/mirrorbrain.conf : config file of mirrorbrain
- config/apache/httpd.conf : config file of Apache httpd
- config/apache/httpd-vhosts.conf : config your virtual host
- sql/mirrors-postgresql.sql : SQL instructions to init mirror list

## See also

Mirrorbrain official site : http://mirrorbrain.org

## Author

Florent Kaisser <florent.pro@kaisser.name>

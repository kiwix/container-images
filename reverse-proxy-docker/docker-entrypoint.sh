#!/bin/bash
set -e

# Warn if the DOCKER_HOST socket does not exist
if [[ $DOCKER_HOST = unix://* ]]; then
	socket_file=${DOCKER_HOST#unix://}
	if ! [ -S $socket_file ]; then
		cat >&2 <<-EOT
			ERROR: you need to share your Docker host socket with a volume at $socket_file
			Typically you should run your jwilder/nginx-proxy with: \`-v /var/run/docker.sock:$socket_file:ro\`
			See the documentation at http://git.io/vZaGJ
		EOT
		socketMissing=1
	fi
fi

# Generate dhparam file if required
# Note: if $DHPARAM_BITS is not defined, generate-dhparam.sh will use 2048 as a default
/app/generate-dhparam.sh $DHPARAM_BITS

# Compute the DNS resolvers for use in the templates - if the IP contains ":", it's IPv6 and must be enclosed in []
export RESOLVERS=$(awk '$1 == "nameserver" {print ($2 ~ ":")? "["$2"]": $2}' ORS=' ' /etc/resolv.conf | sed 's/ *$//g')
if [ "x$RESOLVERS" = "x" ]; then
    echo "Warning: unable to determine DNS resolvers for nginx" >&2
    unset RESOLVERS
fi

# If the user has run the default command and the socket doesn't exist, fail
if [ "$socketMissing" = 1 -a "$1" = forego -a "$2" = start -a "$3" = '-r' ]; then
	exit 1
fi

{ \
   echo "client_max_body_size 8192m;" ; \
} > /etc/nginx/vhost.d/drive.farm.openzim.org


{ \
   echo "limit_req zone=limit burst=100;" ; \
} > /etc/nginx/vhost.d/library.kiwix.org

{ \
  echo "location /catalog/ {" ; \
  echo "  proxy_pass http://library.kiwix.org;" ; \
  echo "  gzip on;" ; \
  echo "  gzip_proxied any;" ; \
  echo '  gzip_types "*";' ; \
  echo "}" ; \
  echo "location /robots.txt {" ; \
  echo "  alias /var/www/library.kiwix.org/robots.txt;" ; \
  echo "}" ; \

  echo "location ^~ /.well-known/acme-challenge/ {" ; \
  echo " auth_basic off;" ; \
  echo " allow all;" ; \
  echo " root /usr/share/nginx/html;" ; \
  echo " try_files \$uri =404;" ; \
  echo " break;" ; \
  echo "}" ; \
} > /etc/nginx/vhost.d/library.kiwix.org_location

# Create WP1 redirects
/etc/cron.hourly/10createWp1Redirects

# Cron is needed to start logrotate on nginx log files
{ \
  echo "#!/bin/sh" ; \
  echo "service nginx reload" ; \
} > /etc/cron.hourly/20reloadNginx && chmod 0500 /etc/cron.hourly/20reloadNginx

service cron start

exec "$@"


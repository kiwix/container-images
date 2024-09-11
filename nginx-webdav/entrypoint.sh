#!/bin/bash

if [[ -n "$USERNAME_FILE" ]] && [[ -n "$PASSWORD_FILE" ]]
then
  USERNAME=$(cat "$USERNAME_FILE")
  PASSWORD=$(cat "$PASSWORD_FILE")
fi

if [[ -n "$USERNAME" ]] && [[ -n "$PASSWORD" ]]
then
    htpasswd -bc /etc/nginx/htpasswd "$USERNAME" "$PASSWORD"
    echo Done.
else
    echo Using no auth.
    sed -i 's%auth_basic "Restricted";% %g' /etc/nginx/conf.d/default.conf
    sed -i 's%auth_basic_user_file /etc/nginx/htpasswd;% %g' /etc/nginx/conf.d/default.conf
fi

if [[ -n "NAME" ]]
then
    sed -i "s/        File Browser/${NAME}/g" /var/www/fancyindex-themes/header.html
    sed -i "s/                        FancyIndex/${NAME}/g" /var/www/fancyindex-themes/header.html
fi

exec "$@"

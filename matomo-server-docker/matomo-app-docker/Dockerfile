FROM matomo:fpm

ENV MATOMO_URL=http://stats.kiwix.org

RUN apt-get update && apt-get install -y --no-install-recommends cron && rm -r /var/lib/apt/lists/*

RUN { \
    echo "5 * * * * www-data /usr/local/bin/php /var/www/html/console core:archive --url $MATOMO_URL" ; \
  } > /etc/cron.d/matomo-archive && chmod 0500 /etc/cron.d/matomo-archive 

RUN { \
    echo "memory_limit = 512M" ; \
} > /usr/local/etc/php/conf.d/memory-limit.ini

CMD service cron start && php-fpm

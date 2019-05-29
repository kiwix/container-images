FROM jwilder/nginx-proxy

RUN { \
    # Increased the number of worker_processes from any number to 4 \
    sed -i 's/\(worker_processes\s*\)[0-9]*;/\14;/' /etc/nginx/nginx.conf; \
    # Increased the number of worker_connections from any number to 19000 \
    sed -i 's/\(worker_connections\s*\)[0-9]*;/\119000;/' /etc/nginx/nginx.conf; \
}

RUN { \
      echo 'proxy_connect_timeout 300;'; \
      echo 'proxy_send_timeout 300;'; \
      echo 'proxy_read_timeout 300;'; \
      echo 'send_timeout 300;'; \
} > /etc/nginx/conf.d/extended_timeout.conf
FROM jwilder/nginx-proxy

RUN { \
    sed -i 's/\(worker_processes\s*\)[0-9]*;/\2;/' /etc/nginx/nginx.conf; \
    sed -i 's/\(worker_connections\s*\)[0-9]*;/\5000;/' /etc/nginx/nginx.conf; \
}

RUN { \
      echo 'proxy_connect_timeout 60;'; \
      echo 'proxy_send_timeout 60;'; \
      echo 'proxy_read_timeout 60;'; \
      echo 'send_timeout 60;'; \
} > /etc/nginx/conf.d/extended_timeout.conf
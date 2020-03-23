FROM debian:buster

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends unzip locales-all nginx python-pip python-virtualenv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV KALITE_HOME /data/kalite
ENV KALITE_VERSION "0.17.4"
# if using multiple langs, separate with `:`
ENV KALITE_LANGS "fr:en"
ENV KALITE_ENV /usr/local/envs/kalite
ENV KALITE_PYTHON "${KALITE_ENV}/bin/python"
ENV KALITE_LANGPACKS_PREFIX /data/shared/kalite_pack_
ENV KALITE_VIDEOS_PREFIX /data/shared/kalite_videos_
ENV ADMIN_ACCOUNT "admin"
ENV ADMIN_PASSWORD "admin_password"
ENV USE_NGINX ""

RUN mkdir -p ${KALITE_HOME}
RUN python2.7 -m virtualenv -p python2.7 --no-site-packages /usr/local/envs/kalite
RUN /usr/local/envs/kalite/bin/python -m pip install ka-lite==${KALITE_VERSION}
RUN /usr/local/envs/kalite/bin/python -m pip install cherrypy==6.1.0

# COPY kalite.vhost /etc/nginx/sites-available/kalite
# COPY kalite.service /etc/systemd/system/kalite.service
# RUN systemctl daemon-reload

COPY kalite.vhost /etc/nginx/sites-enabled/default
COPY kalite-setup.sh /usr/local/bin/kalite-setup.sh
RUN chmod +x /usr/local/bin/kalite-setup.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8008

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/envs/kalite/bin/kalite", "start", "--foreground"]

FROM docker.io/library/python:3.14-alpine3.23
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

RUN set -e \
    && apk update \
    && apk --no-cache add dumb-init \
    && pip install requests==2.33.1 humanfriendly==10.0 xxhash==3.7.0 unidecode==1.4.0

COPY retriever.py /src/

ENV SAVE_TO="/data/catalog.xml"
ENV CMS_API_URL="http://api-service.cms.svc.cluster.local/v1"
ENV CMS_COLLECTION_ID="Kiwix"
ENV REFRESH_EVERY_SECONDS="60"

ENTRYPOINT ["/usr/bin/dumb-init"]
CMD ["/usr/local/bin/python3", "/src/retriever.py"]

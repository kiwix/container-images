FROM docker.io/library/python:3.14-slim-trixie
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

RUN set -e \
    && apt-get update \
    && apt-get install --no-install-recommends -y dumb-init \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir fastapi==0.141.1 uvicorn==0.52.4

COPY main.py /src/

ENV LOG_LEVEL="INFO"

EXPOSE 80

ENTRYPOINT ["/usr/bin/dumb-init"]
CMD ["/usr/local/bin/uvicorn", "--app-dir", "/src", "main:app", "--host", "0.0.0.0", "--port", "80"]

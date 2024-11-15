# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

FROM python:3.12-alpine
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

# Copy pyproject.toml and its dependencies
COPY pyproject.toml README.md /src/
COPY src/donation_api/__about__.py /src/src/donation_api/__about__.py

# Install Python dependencies
RUN pip install --no-cache-dir /src

COPY src /src/src
COPY *.md /src/

# Install + cleanup
RUN pip install --no-cache-dir /src \
 && rm -rf /src \
 && pip install --no-cache-dir uvicorn[standard]==0.32.0

# set STRIPE_USE_LIVE=1 for production (use of live key)
ENV STRIPE_USE_LIVE=0
ENV STRIPE_TEST_KEY=notset
ENV STRIPE_LIVE_KEY=notset
ENV STRIPE_WEBHOOK_SECRET=""

CMD ["uvicorn", "donation_api.entrypoint:app", "--host", "0.0.0.0", "--port", "80"]

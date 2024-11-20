# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

FROM python:3.12-alpine
LABEL org.opencontainers.image.source=https://github.com/kiwix/container-images

# Copy pyproject.toml and its dependencies
COPY pyproject.toml README.md /src/
COPY src/donation_api/__about__.py /src/src/donation_api/__about__.py

# Install Python dependencies
RUN apk --no-cache add dumb-init \
    && pip install --no-cache-dir /src

COPY src /src/src
COPY *.md /src/
COPY entrypoint.sh /usr/local/bin/entrypoint

# Install + cleanup
RUN pip install --no-cache-dir /src \
 && rm -rf /src \
 && pip install --no-cache-dir uvicorn[standard]==0.32.0

# set STRIPE_USE_LIVE=1 for production (use of live key)
ENV STRIPE_USE_LIVE=0
ENV STRIPE_TEST_PUBLISHABLE_KEY=notset
ENV STRIPE_TEST_SECRET_KEY=notset
ENV STRIPE_LIVE_PUBLISHABLE_KEY=notset
ENV STRIPE_LIVE_SECRET_KEY=notset
ENV STRIPE_WEBHOOK_SECRET=""
ENV STRIPE_MINIMAL_AMOUNT=5
ENV STRIPE_MAXIMUM_AMOUNT=999999
ENV STRIPE_WEBHOOK_TESTING_IPS=
ENV ALLOWED_CURRENCIES=chf|usd|eur

ENV MERCHANTID_DOMAIN_ASSOCIATION=
ENV MERCHANTID_DOMAIN_ASSOCIATION_TXT=
ENV APPLEPAY_MERCHANT_IDENTIFIER=
ENV APPLEPAY_DISPLAYNAME=
ENV APPLEPAY_PAYMENT_SESSION_INITIATIVE=
ENV APPLEPAY_PAYMENT_SESSION_INITIATIVE_CONTEXT=
# ENV APPLEPAY_PAYMENT_SESSION_REQ_TIMEOUT_SEC=5
ENV APPLEPAY_MERCHANT_CERTIFICATE=
ENV APPLEPAY_MERCHANT_CERTIFICATE_KEY=
ENV APPLEPAY_MERCHANT_CERTIFICATE_PATH=/etc/ssl/certs/applepay_merchant.pem
ENV APPLEPAY_MERCHANT_CERTIFICATE_KEY_PATH=/etc/ssl/certs/applepay_merchant.key

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/entrypoint"]
CMD ["uvicorn", "donation_api.entrypoint:app", "--host", "0.0.0.0", "--port", "80"]

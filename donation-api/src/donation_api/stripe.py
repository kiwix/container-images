import logging
import re
from http import HTTPStatus
from typing import Annotated, Any

import requests
import stripe
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, ConfigDict
from stripe import Event, StripeError, Webhook

from donation_api.constants import conf

logger = logging.getLogger("uvicorn.error")
stripe.api_key = conf.stripe_secret_api_key

router = APIRouter(
    prefix="/stripe",
    tags=["stripe"],
)


class PaymentIntentRequest(BaseModel):
    """Request Payload for a PaymentIntent creation"""

    amount: int
    currency: str


class PaymentIntent(BaseModel):
    """Our response to PaymentIntent request"""

    secret: str


class PublicConfigResponse(BaseModel):
    publishable_key: str


class StripeWebhookPayload(BaseModel):
    """Stripe-sent payload during the webhook call
    https://stripe.com/docs/webhooks"""

    model_config = ConfigDict(extra="allow")

    id: str
    object: str
    api_version: str
    created: int
    data: dict[str, Any]  # at this point that's enough
    livemode: bool
    pending_webhooks: int
    request: dict[str, Any]
    type: str


class StripeWebhookResponse(BaseModel):
    """Response to Stripe from the Webhook so Stripe is able to record whether
    processing went fine or not"""

    status: str


class ApplePayPaymentSessionRequest(BaseModel):
    # defaulting to test gateway
    validation_url: str = "apple-pay-gateway-cert.apple.com"


class OpaqueApplePayPaymentSession(BaseModel):
    model_config = ConfigDict(extra="allow")

    initiative: str
    initiativeContext: str


async def get_body(request: Request):
    """raw request body"""
    return await request.body()


def can_send_webhook(ip_addr: str) -> bool:
    """whether an IP is allowed to submit webhook requests"""
    if not conf.stripe_on_prod:
        return ip_addr in [
            *conf.stripe_webhook_sender_ips,
            *conf.stripe_webhook_testing_ips,
            "127.0.0.1",
        ]
    return ip_addr in conf.stripe_webhook_sender_ips


@router.get(
    "/config",
    status_code=HTTPStatus.OK,
    responses={
        HTTPStatus.OK: {
            "model": PublicConfigResponse,
            "description": "Health Check passed",
        },
    },
)
async def get_config():
    return {"publishable_key": conf.stripe_publishable_api_key}


@router.get(
    "/health-check",
    status_code=HTTPStatus.OK,
    responses={
        HTTPStatus.INTERNAL_SERVER_ERROR: {
            "description": "Health check failed",
        },
        HTTPStatus.OK: {
            "model": str,
            "description": "Health Check passed",
        },
    },
)
async def check_config():
    errors: list[str] = []

    if conf.stripe_on_prod and not str(stripe.api_key).startswith("sk_live_"):
        errors.append("Missing Live API Key")

    if not conf.stripe_on_prod and not str(stripe.api_key).startswith("sk_test_"):
        errors.append("Missing Test API Key")

    if conf.stripe_on_prod and not conf.stripe_publishable_api_key.startswith(
        "pk_live_"
    ):
        errors.append("Missing Live Publishable API Key")

    if not conf.stripe_on_prod and not conf.stripe_publishable_api_key.startswith(
        "pk_test_"
    ):
        errors.append("Missing Test Publishable API Key")

    if not conf.stripe_webhook_sender_ips:
        errors.append("Missing Stripe IPs")

    if not conf.alllowed_currencies:
        errors.append("Missing currencies list")

    if not conf.applepay_merchant_identifier:
        errors.append("Missing ApplePay merchantIdentifier")

    if not conf.applepay_displayname:
        errors.append("Missing ApplePay displayName")

    if not conf.applepay_payment_session_initiative:
        errors.append("Missing ApplePay session initiative")

    if not conf.applepay_payment_session_initiative_context:
        errors.append("Missing ApplePay session initiative context")

    if not conf.applepay_merchant_certificate_path.read_text():
        errors.append("Missing ApplePay merchant certificate")

    if not conf.applepay_merchant_certificate_key_path.read_text():
        errors.append("Missing ApplePay merchant certificate key")

    if errors:
        raise HTTPException(
            status_code=HTTPStatus.INTERNAL_SERVER_ERROR, detail="\n".join(errors)
        )
    return "OK"


@router.post(
    "/payment-intent",
    responses={
        HTTPStatus.BAD_REQUEST: {
            "description": "PaymentIntent request was not understood",
        },
        HTTPStatus.CREATED: {
            "model": PaymentIntent,
            "description": "Stripe-created PaymentIntent",
        },
    },
    status_code=HTTPStatus.CREATED,
)
async def create_payment_intent(pi_payload: PaymentIntentRequest):
    """API endpoint to receive Book addition requests and add to database"""
    if not re.match(r"[a-z]{3}", pi_payload.currency.lower()):
        logger.error("Currency doesnt look like a currency")
        raise HTTPException(
            status_code=HTTPStatus.BAD_REQUEST,
            detail="Currency doesnt look like a currency",
        )
    if pi_payload.currency not in conf.alllowed_currencies:
        raise HTTPException(
            status_code=HTTPStatus.BAD_REQUEST,
            detail="Currency not supported",
        )

    if (
        pi_payload.amount < conf.stripe_minimal_amount
        or pi_payload.amount > conf.stripe_maximum_amount
    ):
        logger.error("Amount not within range")
        raise HTTPException(
            status_code=HTTPStatus.BAD_REQUEST,
            detail="Amount not within range",
        )
    logger.info(f"PI for {pi_payload.amount} {pi_payload.currency}")
    try:
        intent = stripe.PaymentIntent.create(
            amount=pi_payload.amount,
            currency=pi_payload.currency.lower(),
            use_stripe_sdk=True,
        )
        return {"secret": intent.client_secret}
    except StripeError as exc:
        logger.error(repr(exc))
        raise HTTPException(
            status_code=HTTPStatus.BAD_REQUEST, detail=str(exc)
        ) from exc
    except Exception as exc:
        logger.error(repr(exc))
        raise HTTPException(
            status_code=HTTPStatus.BAD_REQUEST, detail=str(exc)
        ) from exc


@router.post(
    "/webhook",
    responses={
        HTTPStatus.BAD_REQUEST: {
            "description": "Webhook request was not understood",
        },
        HTTPStatus.OK: {
            "model": StripeWebhookResponse,
            "description": "Webhook processing went fine",
        },
    },
    status_code=HTTPStatus.OK,
)
def webhook_received(
    webhook_payload: StripeWebhookPayload,
    request: Request,
    body: bytes = Depends(get_body),
    stripe_signature: Annotated[str | None, Header()] = None,
):
    client_host = request.client.host if request.client else ""
    if not can_send_webhook(client_host):
        logger.error(f"Not from a Strip Webhook IP: {client_host}")
        raise HTTPException(
            status_code=HTTPStatus.FORBIDDEN, detail="Not from a Strip Webhook IP"
        )
    # retrieve the event by verifying the signature using the raw body
    # and secret if webhook signing is configured.
    if conf.stripe_webhook_secret and stripe_signature:
        try:
            event: Event = (
                Webhook.construct_event(  # pyright: ignore [ reportUnknownMemberType]
                    payload=body.decode("UTF-8"),
                    sig_header=stripe_signature,
                    secret=conf.stripe_webhook_secret,
                )
            )
            data = event["data"]
        except Exception as exc:
            logger.error(exc)
            raise HTTPException(
                status_code=HTTPStatus.INTERNAL_SERVER_ERROR,
                detail=f"Event construct failed: {exc!r}",
            ) from exc
        event_type = event["type"]
    else:
        data = webhook_payload.data
        event_type = webhook_payload.type
    data_object = data["object"]

    if event_type == "payment_intent.succeeded":
        logger.info("💰 Payment received!")
        logger.debug(data_object)
    elif event_type == "payment_intent.payment_failed":
        logger.info("❌ Payment failed.")

    return {"status": "success"}


@router.post(
    "/payment-session",
    responses={
        HTTPStatus.BAD_REQUEST: {
            "description": "Request for a Payment Session from ApplePay failed",
        },
        HTTPStatus.OK: {
            "model": OpaqueApplePayPaymentSession,
            "description": "ApplePay Server returned an Opaque Payment Session",
        },
    },
    status_code=HTTPStatus.OK,
)
async def create_payment_session(ps_payload: ApplePayPaymentSessionRequest):
    allowed_domains: list[str] = [
        # Global
        "apple-pay-gateway.apple.com",
        # China
        "cn-apple-pay-gateway.apple.com",
        # Testing (Global)
        "apple-pay-gateway-cert.apple.com",
        # Testing (China)
        "cn-apple-pay-gateway-cert.apple.com",
    ]
    if ps_payload.validation_url not in allowed_domains:
        raise HTTPException(
            status_code=HTTPStatus.FORBIDDEN,
            detail="Validation URL is not in Apple's whitelist",
        )

    payload = {
        "merchantIdentifier": conf.applepay_merchant_identifier,
        "displayName": conf.applepay_displayname,
        "initiative": conf.applepay_payment_session_initiative,
        "initiativeContext": conf.applepay_payment_session_initiative_context,
    }

    data: dict[str, Any] = {}
    resp = requests.post(
        url=f"https://{ps_payload.validation_url}/paymentservices/paymentSession",
        cert=(
            str(conf.applepay_merchant_certificate_path),
            str(conf.applepay_merchant_certificate_key_path),
        ),
        json=payload,
        timeout=conf.applepay_payment_session_request_timeout,
    )
    try:
        data = resp.json()
    except Exception:
        ...
    if resp.status_code != HTTPStatus.OK:
        raise HTTPException(
            status_code=resp.status_code,
            detail=data.get("statusMessage") or "Failed to request payment session",
        )

    return data

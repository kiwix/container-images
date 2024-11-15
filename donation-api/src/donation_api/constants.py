import os
from dataclasses import dataclass, field

import requests


@dataclass
class Constants:
    stripe_on_prod: bool = bool(os.getenv("STRIPE_USE_LIVE") == "1")
    stripe_test_secret_key: str = os.getenv("STRIPE_TEST_SECRET_KEY") or "notset"
    stripe_live_secret_key: str = os.getenv("STRIPE_LIVE_SECRET_KEY") or "notset"
    stripe_test_publishable_key: str = (
        os.getenv("STRIPE_TEST_PUBLISHABLE_KEY") or "notset"
    )
    stripe_live_publishable_key: str = (
        os.getenv("STRIPE_LIVE_PUBLISHABLE_KEY") or "notset"
    )
    stripe_webhook_secret: str = os.getenv("STRIPE_WEBHOOK_SECRET") or ""
    stripe_webhook_sender_ips: list[str] = field(default_factory=list)
    stripe_webhook_testing_ips: list[str] = field(default_factory=list)
    alllowed_currencies: list[str] = field(default_factory=list)
    merchantid_domain_association: str = (
        os.getenv("MERCHANTID_DOMAIN_ASSOCIATION") or ""
    )

    stripe_minimal_amount: int = int(os.getenv("STRIPE_MINIMAL_AMOUNT") or "5")
    stripe_maximum_amount: int = int(os.getenv("STRIPE_MAXIMUM_AMOUNT") or "999999")

    def __post_init__(self):
        self.alllowed_currencies = (
            os.getenv("ALLOWED_CURRENCIES") or "USD|EUR|CHF"
        ).split("|")

        self.stripe_webhook_testing_ips = os.getenv(
            "STRIPE_WEBHOOK_TESTING_IPS", ""
        ).split("|")

        resp = requests.get("https://stripe.com/files/ips/ips_webhooks.txt", timeout=5)
        resp.raise_for_status()
        self.stripe_webhook_sender_ips = resp.text.strip().split("\n")
        if not self.stripe_webhook_sender_ips:
            raise OSError("No Stripe Webhook IPs!")

    @property
    def stripe_secret_api_key(self) -> str:
        if self.stripe_on_prod:
            return self.stripe_live_secret_key
        return self.stripe_test_secret_key

    @property
    def stripe_publishable_api_key(self) -> str:
        if self.stripe_on_prod:
            return self.stripe_live_publishable_key
        return self.stripe_test_publishable_key


conf = Constants()

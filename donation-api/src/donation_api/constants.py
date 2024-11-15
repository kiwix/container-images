import os
from dataclasses import dataclass, field

import requests


@dataclass
class Constants:
    stripe_on_prod: bool = bool(os.getenv("STRIPE_USE_LIVE") == "1")
    stripe_test_key: str = os.getenv("STRIPE_TEST_KEY") or "notset"
    stripe_live_key: str = os.getenv("STRIPE_LIVE_KEY") or "notset"
    stripe_webhook_secret: str = os.getenv("STRIPE_WEBHOOK_SECRET") or ""
    stripe_webhook_sender_ips: list[str] = field(default_factory=list)
    stripe_webhook_testing_ips: list[str] = field(default_factory=list)

    stripe_minimal_amount: float = 1.0
    stripe_maximum_amount: float = 1000000

    def __post_init__(self):
        self.stripe_webhook_testing_ips = os.getenv(
            "STRIPE_WEBHOOK_TESTING_IPS", ""
        ).split("|")

        resp = requests.get("https://stripe.com/files/ips/ips_webhooks.txt", timeout=5)
        resp.raise_for_status()
        self.stripe_webhook_sender_ips = resp.text.strip().split("\n")
        if not self.stripe_webhook_sender_ips:
            raise OSError("No Stripe Webhook IPs!")

    @property
    def stripe_api_key(self) -> str:
        if self.stripe_on_prod:
            return self.stripe_live_key
        return self.stripe_test_key


conf = Constants()

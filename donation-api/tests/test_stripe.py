from http import HTTPStatus

from fastapi.testclient import TestClient

from donation_api.constants import conf


def test_default_to_test():
    assert not conf.stripe_on_prod


def test_check_config(client: TestClient):
    resp = client.get("/v1/stripe/health-check")
    assert resp.status_code == HTTPStatus.INTERNAL_SERVER_ERROR
    assert resp.json().get("detail") == "Missing Test API Key"

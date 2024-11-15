from http import HTTPStatus

from fastapi.testclient import TestClient


def test_root(client: TestClient):
    resp = client.get("/", follow_redirects=False)
    assert resp.status_code == HTTPStatus.PERMANENT_REDIRECT

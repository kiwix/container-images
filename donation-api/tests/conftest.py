import pytest
from fastapi.testclient import TestClient

from donation_api.entrypoint import app


@pytest.fixture(scope="session")
def client():
    yield TestClient(
        app,
        base_url="http://testserver",
        raise_server_exceptions=True,
        root_path="",
        backend="asyncio",
        backend_options=None,
        cookies=None,
        headers=None,
        follow_redirects=True,
    )

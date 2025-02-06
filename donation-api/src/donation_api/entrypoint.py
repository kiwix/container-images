from http import HTTPStatus

from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse

from donation_api import stripe
from donation_api.__about__ import __description__, __title__, __version__
from donation_api.constants import conf

PREFIX = "/v1"


def create_app() -> FastAPI:
    app = FastAPI(
        title=__title__,
        description=__description__,
        version=__version__,
    )

    @app.get("/")
    @app.head("/")
    async def _():
        """HTML Redirect to root of latest version of the API

        Purposedly not an HTTP redirect as Apple Pay verification system
        doesnt like it (apparently)"""

        return Response(
            f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url={PREFIX}/" />
<title>Donation API</title>
</head>
<body>
<p>Current version is located at <a href="{PREFIX}/">{PREFIX}/</a></p>
</body>
</html>"""
        )

    # could be done on infra ; this is a handy shortcut
    if conf.merchantid_domain_association:

        @app.get("/.well-known/apple-developer-merchantid-domain-association")
        @app.head("/.well-known/apple-developer-merchantid-domain-association")
        async def _():
            """Used to validate domain ownership with apple/stripe"""
            return PlainTextResponse(
                conf.merchantid_domain_association, status_code=HTTPStatus.OK
            )

    if conf.merchantid_domain_association_txt:

        @app.get("/.well-known/apple-developer-merchantid-domain-association.txt")
        @app.head("/.well-known/apple-developer-merchantid-domain-association.txt")
        async def _():
            """Used to validate domain ownership with apple"""
            return PlainTextResponse(
                conf.merchantid_domain_association_txt, status_code=HTTPStatus.OK
            )

    api = FastAPI(
        title=__title__,
        description=__description__,
        version=__version__,
        docs_url="/",
        openapi_tags=[
            {
                "name": "stripe",
                "description": "Stripe relay",
            }
        ],
        contact={
            "name": "Kiwix",
            "url": "https://www.kiwix.org/en/contact/",
            "email": "contact+donation@kiwix.org",
        },
        license_info={
            "name": "GNU General Public License v3.0",
            "url": "https://www.gnu.org/licenses/gpl-3.0.en.html",
        },
        # trust any X-Forwarded-* headers from anyone
        # this is assumed to be deployed behind a reverse proxy always
        # and is used solely for (uvicorn's) logs
        proxy_headers=True,
        forwarded_allow_ips="*",
    )

    api.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # API meant to be called by clients everywhere
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    api.include_router(router=stripe.router)

    app.mount(PREFIX, api)

    return app


app = create_app()

from http import HTTPStatus

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from donation_api import stripe
from donation_api.__about__ import __description__, __title__, __version__

PREFIX = "/v1"


def create_app() -> FastAPI:
    app = FastAPI(
        title=__title__,
        description=__description__,
        version=__version__,
    )

    @app.get("/")
    async def _():
        """Redirect to root of latest version of the API"""
        return RedirectResponse(f"{PREFIX}/", status_code=HTTPStatus.PERMANENT_REDIRECT)

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

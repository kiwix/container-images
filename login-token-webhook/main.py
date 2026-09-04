import json
import logging
import os
from fastapi import FastAPI, Header, HTTPException, Depends, Request
from fastapi.exception_handlers import request_validation_exception_handler
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel, ConfigDict

logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper())
logger = logging.getLogger(__name__)

app = FastAPI()

# --- Logging middleware ---

@app.middleware("http")
async def log_request_body(request: Request, call_next):
    body = await request.body()
    response = await call_next(request)

    try:
        parsed = json.loads(body)
        logger.debug("Request received for %s %s:\n%s",
                        request.method, request.url.path, json.dumps(parsed, indent=2))
    except json.JSONDecodeError:
        logger.debug("Request received for %s %s (non-JSON body):\n%r",
                        request.method, request.url.path, body)

    return response


# Reports which field(s) failed Pydantic validation, in addition to the raw
# payload dump above.
@app.exception_handler(RequestValidationError)
async def log_validation_errors(request: Request, exc: RequestValidationError):
    for error in exc.errors():
        field = ".".join(str(part) for part in error["loc"] if part != "body")
        logger.warning("Validation error for %s %s: field '%s' - %s",
                        request.method, request.url.path, field, error["msg"])
    return await request_validation_exception_handler(request, exc)


# --- Auth ---

API_KEY = os.environ["API_KEY"]  # fails fast at startup if not set

def verify_api_key(x_api_key: str = Header(...)):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


# --- Request models (only the fields we actually need) ---
#
# Every field below is optional: the ID token Ory sends us is not guaranteed
# to carry the claims we rely on (e.g. a session created without the
# expected identity schema). Rather than failing the whole request in that
# case, missing fields are simply left out of the response - see the
# webhook endpoint below.

class IdTokenExt(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str | None = None

class IdTokenClaims(BaseModel):
    model_config = ConfigDict(extra="ignore")
    amr: list[str] | None = None
    ext: IdTokenExt | None = None
    aud: list[str] | None = None

class IdToken(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id_token_claims: IdTokenClaims | None = None

class Session(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id_token: IdToken | None = None

class WebhookRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")  # ignore "request", "client_id", etc.

    session: Session | None = None


# --- AAL computation ---

# As per Ory docs,
# "password", "code"  and "oidc" are categorized as first methods of login while
# "totp", "webauthn" and "lookup_secret" are second authentication methods
# https://www.ory.com/docs/kratos/mfa/overview#authenticator-assurance-level-aal
# 
# passkey seems to be a "recent" addition in first factor 
AAL2_FACTOR_1 = {"password", "oidc", "code", "passkey"}
AAL2_FACTOR_2 = {"webauthn", "lookup_secrets", "totp"}

def compute_aal(amr: list[str] | None) -> str:
    amr_set = set(amr or [])
    if amr_set & AAL2_FACTOR_1 and amr_set & AAL2_FACTOR_2:
        return "aal2"
    return "aal1"


# --- Endpoints ---

@app.post("/token-webhook", dependencies=[Depends(verify_api_key)])
async def webhook(payload: WebhookRequest):
    claims = payload.session.id_token.id_token_claims if payload.session and payload.session.id_token else None

    access_token = {}
    if claims is not None:
        access_token["kiwix-aal"] = compute_aal(claims.amr)
        if claims.ext is not None and claims.ext.name is not None:
            access_token["kiwix-name"] = claims.ext.name
        for restricted_client_id in ["d4ee6d1e-e4d3-48a6-8d1a-de93278f231d"]:
            if claims.aud and restricted_client_id in claims.aud and access_token["kiwix-aal"] != "aal2":
                raise HTTPException(status_code=422, detail="2FA is mandatory for this app")


    return {"session": {"access_token": access_token}}

@app.get("/healthz")
def health():
    return {"status": "alive"}
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

# --- Logging middleware (always active; only logs the whole payload when Pydantic
# validation of the incoming body fails, i.e. the response is a 422) ---

@app.middleware("http")
async def log_request_body(request: Request, call_next):
    body = await request.body()
    response = await call_next(request)

    if response.status_code == 422:
        try:
            parsed = json.loads(body)
            logger.debug("Validation failed for %s %s:\n%s",
                         request.method, request.url.path, json.dumps(parsed, indent=2))
        except json.JSONDecodeError:
            logger.debug("Validation failed for %s %s (non-JSON body):\n%r",
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

class IdTokenExt(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str

class IdTokenClaims(BaseModel):
    model_config = ConfigDict(extra="ignore")
    amr: list[str] | None = None
    ext: IdTokenExt

class IdToken(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id_token_claims: IdTokenClaims

class Session(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id_token: IdToken

class WebhookRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")  # ignore "request", "client_id", etc.

    session: Session


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
    claims = payload.session.id_token.id_token_claims
    name = claims.ext.name
    amr = claims.amr

    aal = compute_aal(amr)

    return {
        "session": {
            "access_token": {
                "kiwix-aal": aal,
                "kiwix-name": name,
            }
        }
    }

@app.get("/healthz")
def health():
    return {"status": "alive"}
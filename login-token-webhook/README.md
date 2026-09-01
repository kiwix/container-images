# login-token-webhook

A small FastAPI service used as an [Ory](https://www.ory.com/) token hook.
Ory calls this webhook on every access token creation so it can inject
custom claims into the token, based on data from the ID token of the
session that triggered it.

## What it adds to the access token

Given the incoming ID token claims, the webhook returns two custom claims
that Ory merges into the access token:

- `kiwix-name` — the user's display name, taken from `ext.name` on the ID
  token.
- `kiwix-aal` — the Authenticator Assurance Level (`aal1` or `aal2`) computed
  from the ID token's `amr` (Authentication Methods References), following
  the classification described in the
  [Ory docs on AAL](https://www.ory.com/docs/kratos/mfa/overview#authenticator-assurance-level-aal).
  A session only reaches `aal2` if it combines at least one first-factor
  method (`password`, `oidc`, `code`, `passkey`) with at least one
  second-factor method (`webauthn`, `lookup_secrets`, `totp`).

Both claims are best-effort: if the incoming ID token is missing the data a
claim needs (e.g. no `ext.name`, or no ID token claims at all), the webhook
still succeeds and simply omits that claim rather than failing the request.

### Note on PII

`kiwix-name` is personally identifiable information. Putting it in the
access token is a deliberate choice, not an oversight: it is just a display
name, and having it available in every app's access token lets all apps
show the same display name for a given user. This makes it much easier for
identity/access managers to tell "who is who" when granting permissions
across apps, which was judged worth the (limited) PII exposure.

## How it works

- `POST /token-webhook` (requires an `x-api-key` header matching the
  `API_KEY` environment variable) — the endpoint Ory calls. The request body
  is parsed with Pydantic models that only pick out the fields this service
  actually needs (`session.id_token.id_token_claims.{amr,ext.name}`);
  everything else in the payload is ignored. All of these fields are
  optional — a session missing some or all of them still gets a `200`
  response, just with the corresponding claim(s) left out of
  `access_token`. A `422` is only returned for a genuinely malformed body
  (e.g. non-JSON, or a field present with the wrong type, such as `amr` not
  being a list).
- `GET /healthz` — basic liveness check.
- An HTTP middleware is always active and logs the full raw request body of
  every request at `DEBUG` level, so unexpected payload shapes from Ory can
  be inspected regardless of whether the request ultimately succeeded or
  failed. Separately, a `422` (Pydantic validation failure) also logs a
  `WARNING` naming the specific offending field, which is visible even at
  the default log level.

## Operational usage

Environment variables:

- `API_KEY` (required) — shared secret Ory must send in the `x-api-key`
  header. The service fails to start if it isn't set.
- `LOG_LEVEL` (optional, default `INFO`) — standard Python logging level.
  At the default level, a validation failure logs a short warning naming
  the offending field (e.g. `field 'session.id_token.id_token_claims.ext.name'
  - Field required`). Set `LOG_LEVEL=DEBUG` to additionally log the full raw
  request payload of *every* request, valid or not — useful when
  troubleshooting unexpected payload shapes from Ory, but more verbose (and
  includes PII such as the display name), so it should only be enabled
  temporarily.

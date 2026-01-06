# Auth Server Requirements

This project relies on an external auth service to validate JWTs.

## Required Endpoint

- Verification endpoint (path configurable; default `/whoami`)
  - Auth: `Authorization: Bearer <jwt>`
  - Response: HTTP 200 for valid tokens, non-200 otherwise.

## JWT Expectations

- Short-lived access token (TTL configurable on the auth server).
- Required claims for the issuer: `sub`, `exp`, `iat`, `iss`, `aud`.
- Optional claim: `nonce` (useful for traceability).

## Behavioral Requirements

- The verification endpoint must verify signature, `iss`, `aud`, and `exp`.
- Tokens must be redacted in logs.

## Notes

- This server does not verify JWTs locally; it delegates to `/whoami`.
- Any auth system that issues JWTs and exposes `/whoami` can be used.
- OAuth2 `/introspect` is a common alternative; if the response includes `exp`, the server will forward it via `auth_ok`.

## References

- JWT registered claim names: https://www.rfc-editor.org/rfc/rfc7519#section-4.1

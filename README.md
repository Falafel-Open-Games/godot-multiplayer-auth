# godot-multiplayer-auth

Minimal headless Godot MultiplayerAPI server that enforces JWT-authenticated sessions via an external auth service.

## Goals

- Provide a reusable, open reference for Godot MultiplayerAPI auth gating.
- Keep auth issuer details out of the server; accept any JWT issued by a compatible auth service.
- Stay friendly to HTML5 exports (first-message/RPC auth).

## Contents

- Headless Godot project with a WebSocket MultiplayerAPI server (`godot/`).
- RPC auth contract (`auth`, `auth_ok`, `auth_error`, `ping`, `pong`).
- Config via environment variables (auth base URL, verify path, WS port).
- Minimal run scripts for local testing.

## Docs

- `docs/auth-server.md` — auth server requirements (verification endpoint, default `/whoami`).
- `docs/rpc-api.md` — RPC auth contract.
- `docs/runbook.md` — local run steps and env vars.

## FAQ

Why does auth happen via an RPC call instead of WebSocket headers?

WebSockets start as an HTTP request with an `Upgrade: websocket` header. In native clients you can often attach
`Authorization: Bearer <jwt>` to that upgrade request so the server can accept or reject the connection before it opens.
In browser/HTML5 exports, JavaScript cannot set custom WebSocket headers, so the only portable option is to authenticate
after connect using the first RPC message (`auth(token)`).

Why not verify JWTs locally with JWKS?

This server runs in GDScript and does not have built-in Ed25519/JWT verification. Instead, it delegates verification to
an external auth service via a configurable endpoint (default `/whoami`). That keeps the server lightweight and works
consistently in HTML5 exports.

## License

MIT. See `LICENSE`.

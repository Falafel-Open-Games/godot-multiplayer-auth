# godot-multiplayer-auth

Minimal headless Godot MultiplayerAPI server that enforces JWT-authenticated sessions via an external auth service.

## Goals

- Provide a reusable, open reference for Godot MultiplayerAPI auth gating.
- Keep auth issuer details out of the server; accept any JWT issued by a compatible auth service.
- Stay friendly to HTML5 exports (first-message/RPC auth).

## Planned Contents

- Headless Godot project with a WebSocket MultiplayerAPI server.
- RPC auth contract (`auth`, `auth_ok`, `auth_error`, `ping`, `pong`).
- Config via environment variables (auth base URL, WS port, audience/issuer).
- Minimal run scripts for local testing.

## Docs

- `docs/auth-server.md` — auth server requirements (`/whoami` contract).
- `docs/rpc-api.md` — RPC auth contract.

## License

MIT. See `LICENSE`.

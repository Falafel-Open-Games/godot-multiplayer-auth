# Godot Headless WebSocket Server

This is a minimal, headless Godot WebSocket server that validates JWTs by calling a configurable auth endpoint (default `/whoami`).

## Run It

1. Start your auth service and ensure it can issue JWTs.
2. Launch the MultiplayerAPI server (WebSocketMultiplayerPeer):
   ```sh
   just server
   ```
3. Launch the sample client (requires `AUTH_TOKEN`):
   ```sh
   just client "<jwt_token>"
   ```

Environment variables:

- `WS_PORT` (default `8081`)
- `AUTH_BASE_URL` (default `http://127.0.0.1:3000`)
- `AUTH_VERIFY_PATH` (default `/whoami`)
- `WS_URL` (client, default `ws://127.0.0.1:8081`)
- `AUTH_TOKEN` (client, required)

## RPC API

See `docs/rpc-api.md` for the full RPC contract.

## Notes

- The server does not attempt to read upgrade headers; auth is RPC-only.
- Unauthenticated peers are disconnected after a short timeout (~5s).
- Tokens are always redacted in logs; no full JWTs are printed.

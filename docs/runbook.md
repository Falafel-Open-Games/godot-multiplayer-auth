# Godot Headless WebSocket Auth (Server + Client)

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
  - Local bind port for the headless WebSocket server.
- `AUTH_BASE_URL` (default `http://127.0.0.1:3000`)
  - Auth service base URL used to validate JWTs.
- `AUTH_VERIFY_PATH` (default `/whoami`)
  - Path on the auth service for token verification.
- `WS_URL` (client, default `ws://127.0.0.1:8081`)
  - Client connection target for `just client`.
- `AUTH_TOKEN` (client, required)
  - JWT the client sends via the `auth(token)` RPC.

## Deploy (Fly.io)

Prereqs:

- `flyctl` installed and authenticated (`fly auth login`).
- A publicly reachable auth service URL.

1. Create the Fly app if needed:
   ```sh
   fly launch --no-deploy
   ```
2. Generate a Fly config from the template:
   ```sh
   sed "s/YOUR_APP_NAME/<your-app-name>/" fly.example.toml > fly.toml
   ```
   If deploying from GitHub Actions, set `FLY_APP_NAME` as a repo variable.
3. Configure the auth service base URL:
   ```sh
   fly secrets set AUTH_BASE_URL="https://<auth-service-host>"
   ```
   Optional:
   ```sh
   fly secrets set AUTH_VERIFY_PATH="/whoami"
   ```
4. Deploy the container:
   ```sh
   fly deploy
   ```
5. Verify connectivity from a client:
   ```sh
   WS_URL="wss://<your-app>.fly.dev" just client "<jwt_token>"
   ```

## Web Export Artifact

- GitHub Actions builds the HTML export and publishes it to the `latest` release as `godot-ws-web-html.tar.gz`.
- Consumers can download this artifact to populate their own demo hosting.

## RPC API

See `docs/rpc-api.md` for the full RPC contract.

## Notes

- The server does not attempt to read upgrade headers; auth is RPC-only.
- Unauthenticated peers are disconnected after a short timeout (~5s).
- Tokens are always redacted in logs; no full JWTs are printed.

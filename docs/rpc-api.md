# RPC API

The server uses `MultiplayerAPI` + `WebSocketMultiplayerPeer`. Clients must call RPCs on the shared root node.

## Client → Server

- `auth(token: String)`
  - Required as the first call after connect.
  - Token is a JWT issued by the external auth server.
- `ping()`
  - Requires an authenticated session.

## Server → Client

- `auth_ok(exp: int)`
  - Sent when the JWT is valid.
  - `exp` is the JWT expiry timestamp (seconds since epoch); `0` if the verify endpoint does not return it.
- `auth_error(reason: String)`
  - Sent on auth failure before disconnect (currently always `unauthorized`).
- `pong()`
  - Reply to `ping()`.

## Behavior

- Unauthenticated peers are disconnected after a short timeout (~5s).
- Auth is RPC-only; upgrade headers are not used.

## References

- Godot MultiplayerAPI: https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html
- Godot WebSocketMultiplayerPeer: https://docs.godotengine.org/en/stable/classes/class_websocketmultiplayerpeer.html

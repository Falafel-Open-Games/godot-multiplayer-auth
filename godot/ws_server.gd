extends Node

# === Configuration ===
const AUTH_TIMEOUT_MS = 5000
const DEFAULT_WS_PORT = 8081
const DEFAULT_AUTH_BASE_URL = "http://127.0.0.1:3000"
const DEFAULT_AUTH_VERIFY_PATH = "/whoami"

# === Runtime state ===
var auth_base_url: String
var auth_verify_path: String
var clients := {}

# === Lifecycle: boot the WebSocket server ===
func _ready() -> void:
	auth_base_url = OS.get_environment("AUTH_BASE_URL")
	if auth_base_url == "":
		auth_base_url = DEFAULT_AUTH_BASE_URL
	auth_verify_path = OS.get_environment("AUTH_VERIFY_PATH")
	if auth_verify_path == "":
		auth_verify_path = DEFAULT_AUTH_VERIFY_PATH
	var port_env = OS.get_environment("WS_PORT")
	var port = DEFAULT_WS_PORT
	if port_env != "":
		port = int(port_env)
	var ws_peer = WebSocketMultiplayerPeer.new()
	var err = ws_peer.create_server(port)
	if err != OK:
		push_error("WS server create failed: %s" % err)
		return
	multiplayer.multiplayer_peer = ws_peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	set_process(true)
	print("WS server listening on %s, auth via %s" % [port, auth_base_url])

# === Main loop: poll peer and enforce auth timeout ===
func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.poll()
	var now = _now_ms()
	for peer_id in clients.keys():
		var client = clients[peer_id]
		# Close unauthenticated connections that do not send AUTH quickly.
		if not client.authed and now - client.connected_at > AUTH_TIMEOUT_MS:
			_reject_auth(peer_id, "auth_timeout")

# === Connection handlers: track client lifecycle ===
func _on_peer_connected(peer_id: int) -> void:
	clients[peer_id] = {
		"authed": false,
		"connected_at": _now_ms(),
		"auth_inflight": false,
	}
	print("WS peer connected: %s" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	clients.erase(peer_id)
	print("WS peer disconnected: %s" % peer_id)

# === RPC entrypoints: AUTH gate + basic PING/PONG ===
@rpc("any_peer", "reliable")
func auth(token: String) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if peer_id == 0 or not clients.has(peer_id):
		return
	if token == "":
		_reject_auth(peer_id, "missing_token")
		return
	if clients[peer_id].auth_inflight:
		return
	clients[peer_id].auth_inflight = true
	print("Auth attempt: %s %s" % [peer_id, _redact_token(token)])
	_verify_token(peer_id, token)

@rpc("any_peer", "reliable")
func ping() -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not _is_authed(peer_id):
		_reject_auth(peer_id, "unauthorized")
		return
	rpc_id(peer_id, "pong")

# === RPC responses (client-side stubs; server invokes these) ===
@rpc("authority", "reliable")
func auth_ok(_exp: int) -> void:
	pass

@rpc("authority", "reliable")
func auth_error(_reason: String) -> void:
	pass

@rpc("authority", "reliable")
func pong() -> void:
	pass

# === Auth verification: call /whoami and mark session ===
func _verify_token(peer_id: int, token: String) -> void:
	var request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(
		_on_verify_completed.bind(peer_id, request, token)
	)
	var headers = ["Authorization: Bearer %s" % token]
	# Use /whoami to validate the token and mirror the JWT claims we need.
	var err = request.request(
		auth_base_url + _normalize_verify_path(auth_verify_path),
		headers,
		HTTPClient.METHOD_GET
	)
	if err != OK:
		request.queue_free()
		_reject_auth(peer_id, "auth_request_failed")

# === Auth completion: validate response and emit AUTH_OK ===
func _on_verify_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	request: HTTPRequest,
	token: String
) -> void:
	request.queue_free()
	if not clients.has(peer_id):
		return
	clients[peer_id].auth_inflight = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_reject_auth(peer_id, "auth_request_failed")
		return
	if response_code != 200:
		_reject_auth(peer_id, "invalid_token")
		return
	var payload = {}
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err == OK and typeof(json.data) == TYPE_DICTIONARY:
		payload = json.data
	clients[peer_id].authed = true
	var address = str(payload.get("address", ""))
	if address == "":
		address = str(payload.get("sub", ""))
	clients[peer_id].address = address
	clients[peer_id].nonce = str(payload.get("nonce", ""))
	clients[peer_id].exp = int(payload.get("exp", 0))
	rpc_id(
		peer_id,
		"auth_ok",
		clients[peer_id].exp
	)
	print("Auth ok: %s %s" % [peer_id, _redact_token(token)])

func _reject_auth(peer_id: int, reason: String) -> void:
	if not clients.has(peer_id):
		return
	rpc_id(peer_id, "auth_error", reason)
	_disconnect_peer(peer_id, reason)

func _disconnect_peer(peer_id: int, reason: String) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)
	clients.erase(peer_id)
	print("WS peer closed: %s %s" % [peer_id, reason])

func _is_authed(peer_id: int) -> bool:
	return clients.has(peer_id) and clients[peer_id].authed

func _normalize_verify_path(path: String) -> String:
	if path == "":
		return DEFAULT_AUTH_VERIFY_PATH
	if path.begins_with("/"):
		return path
	return "/" + path

# === Utilities: token redaction, time ===
func _redact_token(token: String) -> String:
	if token.length() <= 12:
		return "[redacted]"
	return "%s...%s" % [token.substr(0, 6), token.substr(token.length() - 4, 4)]

func _now_ms() -> int:
	return Time.get_ticks_msec()

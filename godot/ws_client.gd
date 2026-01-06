extends Node

signal status(message: String)
signal auth_ready(exp_ts: int)
signal auth_failed(reason: String)

# === Configuration ===
const DEFAULT_WS_URL = "ws://127.0.0.1:8081"
const DEFAULT_AUTH_TIMEOUT_MS = 5000
const HEARTBEAT_INTERVAL_MS = 1000
const HEARTBEAT_COUNT = 3

# === Runtime state ===
var ws_url: String
var auth_token: String
var auth_deadline_ms := 0
var authed := false
var next_ping_ms := 0
var remaining_pings := 0
var pending_pongs := 0
var headless_mode := false

# === Lifecycle: connect to server ===
func _ready() -> void:
	if OS.has_feature("web"):
		_emit_status("Web export detected; WS client ready.")
		set_process(true)
		return
	ws_url = OS.get_environment("WS_URL")
	if ws_url == "":
		ws_url = DEFAULT_WS_URL
	auth_token = OS.get_environment("AUTH_TOKEN")
	if auth_token == "":
		push_error("AUTH_TOKEN is required for headless tests")
		return
	headless_mode = true
	connect_with_token(ws_url, auth_token)

# === Main loop: poll peer and enforce auth timeout ===
func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.poll()
	var now = Time.get_ticks_msec()
	if auth_deadline_ms > 0 and now > auth_deadline_ms:
		_handle_error("Auth timeout")
	if authed and remaining_pings > 0 and now >= next_ping_ms:
		remaining_pings -= 1
		pending_pongs += 1
		next_ping_ms = now + HEARTBEAT_INTERVAL_MS
		ping.rpc_id(1)

func _on_connected() -> void:
	_emit_status("Connected, sending auth")
	auth.rpc_id(1, auth_token)

func _on_connection_failed() -> void:
	_handle_error("Connection failed")

func _on_server_disconnected() -> void:
	_handle_error("Server disconnected")

# === RPC responses (server → client) ===
@rpc("authority", "reliable")
func auth_ok(exp_ts: int) -> void:
	auth_deadline_ms = 0
	authed = true
	remaining_pings = HEARTBEAT_COUNT
	pending_pongs = 0
	next_ping_ms = Time.get_ticks_msec()
	_emit_status("Auth ok: exp=%s" % exp_ts)
	auth_ready.emit(exp_ts)

@rpc("authority", "reliable")
func auth_error(reason: String) -> void:
	auth_deadline_ms = 0
	_handle_error("Auth error: %s" % reason)
	auth_failed.emit(reason)

@rpc("authority", "reliable")
func pong() -> void:
	_emit_status("Pong received")
	if pending_pongs > 0:
		pending_pongs -= 1
	if remaining_pings == 0 and pending_pongs == 0:
		if headless_mode:
			get_tree().quit(0)

# === RPC requests (client → server) ===
@rpc("any_peer", "reliable")
func auth(_token: String) -> void:
	pass

@rpc("any_peer", "reliable")
func ping() -> void:
	pass

# === Utilities ===
func connect_with_token(url: String, token: String) -> void:
	ws_url = url
	auth_token = token
	if ws_url == "" or auth_token == "":
		_handle_error("Missing WS URL or auth token.")
		return
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	var ws_peer = WebSocketMultiplayerPeer.new()
	var err = ws_peer.create_client(ws_url)
	if err != OK:
		_handle_error("WS client connect failed: %s" % err)
		return
	multiplayer.multiplayer_peer = ws_peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	auth_deadline_ms = Time.get_ticks_msec() + DEFAULT_AUTH_TIMEOUT_MS
	authed = false
	remaining_pings = 0
	pending_pongs = 0
	next_ping_ms = 0
	_emit_status("WS client connecting to %s with %s" % [ws_url, _redact_token(auth_token)])
	set_process(true)

func _emit_status(message: String) -> void:
	status.emit(message)
	print(message)

func _handle_error(message: String) -> void:
	status.emit(message)
	push_error(message)
	if headless_mode:
		get_tree().quit(1)

func _redact_token(token: String) -> String:
	if token.length() <= 12:
		return "[redacted]"
	return "%s...%s" % [token.substr(0, 6), token.substr(token.length() - 4, 4)]

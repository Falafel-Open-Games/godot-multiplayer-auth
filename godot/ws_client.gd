extends Node

signal status(message: String)
signal auth_ready(exp_ts: int)
signal auth_failed(reason: String)
signal connection_closed(reason: String)

# === Configuration ===
const DEFAULT_WS_URL = "ws://127.0.0.1:8081"
const DEFAULT_AUTH_TIMEOUT_MS = 5000
const HEARTBEAT_INTERVAL_MS = 1000
const HEARTBEAT_COUNT = 3
const RECONNECT_DELAY_MS = 5000
const RECONNECT_MAX_ATTEMPTS = 0 # 0 = unlimited

# === Runtime state ===
var ws_url: String
var auth_token: String
var auth_deadline_ms := 0
var authed := false
var next_ping_ms := 0
var remaining_pings := 0
var pending_pongs := 0
var headless_mode := false
var last_auth_error_reason := ""
var reconnect_attempts := 0
var reconnect_pending := false
var allow_reconnect := true

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
	auth_token = auth_token.strip_edges()
	headless_mode = true
	connect_with_token(ws_url, auth_token)

# === Main loop: poll peer and enforce auth timeout ===
func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.poll()
	var now = Time.get_ticks_msec()
	if auth_deadline_ms > 0 and now > auth_deadline_ms:
		auth_deadline_ms = 0
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
	var reason = ""
	if last_auth_error_reason != "":
		reason = " (last auth error: %s)" % last_auth_error_reason
	_handle_error("Server disconnected%s" % reason)

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
	last_auth_error_reason = reason
	allow_reconnect = false
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
func connect_with_token(url: String, token: String, reset_reconnect: bool = true) -> void:
	ws_url = url
	auth_token = token.strip_edges()
	if ws_url == "" or auth_token == "":
		_handle_error("Missing WS URL or auth token.")
		return
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	var ws_peer = WebSocketMultiplayerPeer.new()
	var err = ws_peer.create_client(ws_url)
	if err != OK:
		_handle_error("WS client connect failed: %s" % err)
		return
	multiplayer.multiplayer_peer = ws_peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	auth_deadline_ms = Time.get_ticks_msec() + DEFAULT_AUTH_TIMEOUT_MS
	authed = false
	remaining_pings = 0
	pending_pongs = 0
	next_ping_ms = 0
	last_auth_error_reason = ""
	if reset_reconnect:
		reconnect_attempts = 0
		reconnect_pending = false
		allow_reconnect = true
	_emit_status("WS client connecting to %s with %s" % [ws_url, _redact_token(auth_token)])
	set_process(true)

func _emit_status(message: String) -> void:
	status.emit(message)
	print(message)

func _handle_error(message: String) -> void:
	status.emit(message)
	push_error(message)
	auth_deadline_ms = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	set_process(false)
	connection_closed.emit(message)
	if not headless_mode:
		_schedule_reconnect()
	if headless_mode:
		get_tree().quit(1)

func _schedule_reconnect() -> void:
	if not allow_reconnect:
		return
	if reconnect_pending:
		return
	if RECONNECT_MAX_ATTEMPTS > 0 and reconnect_attempts >= RECONNECT_MAX_ATTEMPTS:
		_emit_status("Reconnect attempts exhausted.")
		return
	reconnect_pending = true
	reconnect_attempts += 1
	_emit_status("Reconnecting in %s ms (attempt %s)" % [RECONNECT_DELAY_MS, reconnect_attempts])
	var timer = get_tree().create_timer(RECONNECT_DELAY_MS / 1000.0)
	timer.timeout.connect(func() -> void:
		reconnect_pending = false
		connect_with_token(ws_url, auth_token, false)
	)

func _redact_token(token: String) -> String:
	if token.length() <= 12:
		return "[redacted]"
	return "%s...%s" % [token.substr(0, 6), token.substr(token.length() - 4, 4)]

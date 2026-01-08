extends Control

@export var output: RichTextLabel
@export var login_button: Button

var jwt_token := ""
var jwt_expires_at := ""
var ws_client = null
var wrapper_auth: WrapperAuthBridge = null

func _ready() -> void:
	ws_client = get_parent()
	wrapper_auth = WrapperAuthBridge.new()
	add_child(wrapper_auth)
	wrapper_auth.auth_token_received.connect(_on_auth_token_received)
	wrapper_auth.auth_error.connect(_on_auth_error)
	output.text = ""
	_log_line("Please sign in")
	login_button.pressed.connect(_on_login_pressed)
	_bind_ws_signals()

func _on_login_pressed() -> void:
	var error = ""
	if wrapper_auth != null:
		error = wrapper_auth.request_sign_in()
	if error != "":
		_log_line(error)
		return
	_log_line("Signing in...")

func _on_auth_token_received(token: String, expires_at: String, ws_url: String) -> void:
	jwt_token = token
	jwt_expires_at = expires_at
	_log_line("Token acquired — ready to connect.")
	if ws_client != null and ws_client.has_method("connect_with_token"):
		_log_line("Connecting to WS server...")
		ws_client.connect_with_token(ws_url, jwt_token)

func _on_auth_error(message: String) -> void:
	_log_line(message)

func _bind_ws_signals() -> void:
	if ws_client == null:
		return
	if ws_client.has_signal("status"):
		ws_client.status.connect(_on_ws_status)
	if ws_client.has_signal("auth_ready"):
		ws_client.auth_ready.connect(_on_ws_auth_ready)
	if ws_client.has_signal("auth_failed"):
		ws_client.auth_failed.connect(_on_ws_auth_failed)
	if ws_client.has_signal("connection_closed"):
		ws_client.connection_closed.connect(_on_ws_closed)

func _on_ws_status(message: String) -> void:
	_log_line(message)

func _on_ws_auth_ready(_exp_ts: int) -> void:
	_log_line("WS authenticated.")

func _on_ws_auth_failed(reason: String) -> void:
	_log_line("WS auth failed: %s" % reason)

func _on_ws_closed(reason: String) -> void:
	_log_line("WS closed: %s" % reason)

func _log_line(message: String) -> void:
	output.append_text(message + "\n")

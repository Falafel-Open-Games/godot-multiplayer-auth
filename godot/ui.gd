extends Control

@export var output: RichTextLabel
@export var login_button: Button

var jwt_token := ""
var jwt_expires_at := ""
var js_callback = null
var ws_client = null

func _ready() -> void:
	ws_client = get_parent()
	output.text = ""
	_log_line("Please sign in")
	login_button.pressed.connect(_on_login_pressed)
	_register_message_listener()
	_bind_ws_signals()

func _on_login_pressed() -> void:
	if not _is_web():
		_log_line("Wallet sign-in is available in HTML exports only.")
		return
	_log_line("Signing in...")
	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		output.text = "Wrapper not available."
		return
	var parent = window.parent
	if parent == null:
		_log_line("Wrapper not available.")
		return
	var tabletop = parent.tabletopAuth
	if tabletop == null:
		_log_line("Wrapper auth not available.")
		return
	tabletop.requestSignIn()

func _register_message_listener() -> void:
	if not _is_web():
		return
	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		return
	js_callback = JavaScriptBridge.create_callback(_on_js_message)
	window.addEventListener("message", js_callback)

func _on_js_message(args) -> void:
	if args.is_empty():
		return
	var event = args[0]
	if event == null:
		return
	var data = event.data
	if data == null:
		return
	var message_type = ""
	if data is Dictionary:
		message_type = str(data.get("type", ""))
	else:
		message_type = str(data.type)
	if message_type != "AUTH_TOKEN":
		return
	var token = ""
	var expires_at = ""
	if data is Dictionary:
		token = str(data.get("token", ""))
		expires_at = str(data.get("expires_at", ""))
	else:
		token = str(data.token)
		expires_at = str(data.expires_at)
	if token == "":
		_log_line("Login failed.")
		return
	jwt_token = token
	jwt_expires_at = expires_at
	_log_line("Token acquired — ready to connect.")
	var ws_url = ""
	if data is Dictionary:
		ws_url = str(data.get("ws_url", ""))
	else:
		ws_url = str(data.ws_url)
	if ws_url == "":
		_log_line("WS URL missing; configure in wrapper.")
		return
	if ws_client != null and ws_client.has_method("connect_with_token"):
		_log_line("Connecting to WS server...")
		ws_client.connect_with_token(ws_url, jwt_token)

func _is_web() -> bool:
	return OS.has_feature("web")

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

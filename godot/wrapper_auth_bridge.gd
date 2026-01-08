extends Node

class_name WrapperAuthBridge

signal auth_token_received(token: String, expires_at: String, ws_url: String)
signal auth_error(message: String)

var window = null
var js_callback = null

func _ready() -> void:
	if not _is_web():
		return
	window = JavaScriptBridge.get_interface("window")
	if window == null:
		return
	js_callback = JavaScriptBridge.create_callback(_on_js_message)
	window.addEventListener("message", js_callback)

func _exit_tree() -> void:
	if window != null and js_callback != null:
		window.removeEventListener("message", js_callback)

func request_sign_in() -> String:
	if not _is_web():
		return "Wallet sign-in is available in HTML exports only."
	if window == null:
		window = JavaScriptBridge.get_interface("window")
	if window == null:
		return "Wrapper not available."
	var parent = window.parent
	if parent == null:
		return "Wrapper not available."
	var tabletop = parent.tabletopAuth
	if tabletop == null:
		return "Wrapper auth not available."
	tabletop.requestSignIn()
	return ""

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
		auth_error.emit("Login failed.")
		return
	var ws_url = ""
	if data is Dictionary:
		ws_url = str(data.get("ws_url", ""))
	else:
		ws_url = str(data.ws_url)
	if ws_url == "":
		auth_error.emit("WS URL missing; configure in wrapper.")
		return
	auth_token_received.emit(token, expires_at, ws_url)

func _is_web() -> bool:
	return OS.has_feature("web")

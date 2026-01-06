default:
	@just --list

server:
	godot --headless --path godot --scene res://ws_server.tscn

test:
	node scripts/godot-ws-auth.mjs

client token ws_url="ws://127.0.0.1:8081":
	AUTH_TOKEN="{{token}}" WS_URL="{{ws_url}}" godot --headless --path godot --scene res://ws_client.tscn

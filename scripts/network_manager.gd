extends Node

# Emitted when the server matches us with an opponent
signal matched(role)
# Emitted when opponent picks their character on char select
signal opponent_char_selected(character, bg_index)
# Emitted when opponent moves their cursor on char select (before confirming)
signal opponent_char_hovered(index)
# Emitted when server confirms both players are ready — fight starts
signal game_start(p1_char, p2_char, bg_index)
# Emitted each time we receive opponent's input for a given frame
signal input_received(frame, keys)
# Emitted when the opponent disconnects mid-game
signal opponent_disconnected()

# Input bitmask bit positions
const BIT_LEFT  := 1
const BIT_RIGHT := 2
const BIT_JUMP  := 4
const BIT_DOWN  := 8
const BIT_PUNCH := 16
const BIT_KICK  := 32

const SERVER_URL := "wss://dev.writecraft.io/ws"

var local_role: String = ""         # "p1" or "p2"
var input_delay_frames: int = 3     # Calibrated from RTT at connect time

# Key = frame number, value = int bitmask
var local_input_buffer: Dictionary = {}
var remote_input_buffer: Dictionary = {}
var remote_state_hash_buffer: Dictionary = {}  # frame -> int hash from remote

var _client: WebSocketClient = null
var _connected: bool = false
var _ping_count: int = 0
var _rtt_sum: int = 0
var _state: String = "disconnected"  # disconnected | connecting | in_queue | matched | in_game


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS


func _process(_delta: float) -> void:
	if _client != null:
		_client.poll()


func connect_to_server(url: String = SERVER_URL) -> void:
	local_input_buffer.clear()
	remote_input_buffer.clear()
	local_role = ""
	_ping_count = 0
	_rtt_sum = 0

	_client = WebSocketClient.new()
	_client.connect("connection_established", self, "_on_connected")
	_client.connect("connection_closed", self, "_on_closed", [], CONNECT_ONESHOT)
	_client.connect("connection_error", self, "_on_error")
	_client.connect("data_received", self, "_on_data")

	var err = _client.connect_to_url(url)
	if err != OK:
		push_error("[NetworkManager] connect_to_url failed: " + str(err))
		return

	_state = "connecting"
	print("[NetworkManager] Connecting to " + url)


func disconnect_from_server() -> void:
	if _client != null:
		_client.disconnect_from_host()
		_client = null
	_state = "disconnected"
	_connected = false


func send_join_queue(player_name: String = "Player") -> void:
	_send_json({"type": "join_queue", "name": player_name})
	_state = "in_queue"


func send_char_select(character: String, bg_index: int) -> void:
	_send_json({"type": "char_select", "character": character, "background_index": bg_index})


func send_char_hover(index: int) -> void:
	_send_json({"type": "char_hover", "index": index})


func send_input_frame(frame: int, keys: int, state_hash: int = 0) -> void:
	_send_json({"type": "input_frame", "frame": frame, "keys": keys, "sh": state_hash})


func _measure_rtt() -> void:
	_send_json({"type": "ping", "ts": OS.get_ticks_msec()})


func _send_json(data: Dictionary) -> void:
	if _client == null or not _connected:
		return
	var text = JSON.print(data)
	_client.get_peer(1).put_packet(text.to_utf8())


func _on_connected(_proto: String) -> void:
	_connected = true
	_state = "connected"
	print("[NetworkManager] Connected")
	# Measure RTT three times to calibrate delay
	for _i in range(3):
		_measure_rtt()


func _on_closed(was_clean: bool) -> void:
	_connected = false
	print("[NetworkManager] Disconnected (clean=%s)" % was_clean)
	if _state == "in_game":
		emit_signal("opponent_disconnected")
	_state = "disconnected"


func _on_error() -> void:
	_connected = false
	_state = "disconnected"
	push_error("[NetworkManager] Connection error")


func _on_data() -> void:
	if _client == null:
		return
	var packet = _client.get_peer(1).get_packet()
	var text = packet.get_string_from_utf8()
	var result = JSON.parse(text)
	if result.error != OK:
		push_error("[NetworkManager] JSON parse error: " + text)
		return
	_handle_message(result.result as Dictionary)


func _handle_message(msg: Dictionary) -> void:
	match msg.get("type", ""):
		"matched":
			local_role = msg["role"]
			_state = "matched"
			print("[NetworkManager] Matched as " + local_role + " in room " + msg["room_id"])
			emit_signal("matched", local_role)

		"opponent_char":
			emit_signal("opponent_char_selected", msg["character"], msg["background_index"])

		"opponent_char_hover":
			emit_signal("opponent_char_hovered", int(msg["index"]))

		"game_start":
			_state = "in_game"
			emit_signal("game_start", msg["p1_char"], msg["p2_char"], msg["bg_index"])

		"input_relay":
			var frame: int = msg["frame"]
			var keys: int = msg["keys"]
			remote_input_buffer[frame] = keys
			if msg.has("sh"):
				remote_state_hash_buffer[frame] = int(msg["sh"])
			emit_signal("input_received", frame, keys)

		"pong":
			var rtt_ms: int = OS.get_ticks_msec() - int(msg["ts"])
			_rtt_sum += rtt_ms
			_ping_count += 1
			if _ping_count >= 3:
				_calibrate_delay()

		"opponent_disconnected":
			emit_signal("opponent_disconnected")


func _calibrate_delay() -> void:
	var avg_rtt_ms := _rtt_sum / _ping_count
	# One-way trip = rtt/2. Convert to frames at 30 fps.
	var frame_ms := 1000.0 / 30.0
	var one_way_frames := int(ceil(avg_rtt_ms / 2.0 / frame_ms))
	input_delay_frames = max(3, one_way_frames + 1)
	print("[NetworkManager] RTT=%dms → input_delay=%d frames" % [avg_rtt_ms, input_delay_frames])
	send_join_queue()

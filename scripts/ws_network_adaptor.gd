extends "res://addons/godot-rollback-netcode/NetworkAdaptor.gd"

# Peer IDs: p1 = 1 (host), p2 = 2
const P1_ID := 1
const P2_ID := 2

func attach_network_adaptor(_sync_manager) -> void:
	NetworkManager.connect("sm_message_received", self, "_on_sm_message")
	# Replay buffered remote_start if sm_remote_start arrived before this adaptor connected
	if NetworkManager._pending_sm_remote_start:
		NetworkManager._pending_sm_remote_start = false
		emit_signal("received_remote_start")

func detach_network_adaptor(_sync_manager) -> void:
	if NetworkManager.is_connected("sm_message_received", self, "_on_sm_message"):
		NetworkManager.disconnect("sm_message_received", self, "_on_sm_message")

func start_network_adaptor(_sync_manager) -> void:
	pass

func stop_network_adaptor(_sync_manager) -> void:
	pass

func send_ping(_peer_id: int, msg: Dictionary) -> void:
	NetworkManager.send_sm_message({"type": "sm_ping", "payload": msg})

func send_ping_back(_peer_id: int, msg: Dictionary) -> void:
	NetworkManager.send_sm_message({"type": "sm_ping_back", "payload": msg})

func send_remote_start(_peer_id: int) -> void:
	NetworkManager.send_sm_message({"type": "sm_remote_start"})

func send_remote_stop(_peer_id: int) -> void:
	NetworkManager.send_sm_message({"type": "sm_remote_stop"})

func send_input_tick(_peer_id: int, msg: PoolByteArray) -> void:
	NetworkManager.send_sm_message({"type": "sm_input_tick", "data": Marshalls.raw_to_base64(msg)})

func is_network_host() -> bool:
	return NetworkManager.local_role == "p1"

func is_network_master_for_node(node: Node) -> bool:
	return node.get_network_master() == get_network_unique_id()

func get_network_unique_id() -> int:
	return P1_ID if NetworkManager.local_role == "p1" else P2_ID

func _on_sm_message(msg: Dictionary) -> void:
	var opponent_id: int = P2_ID if NetworkManager.local_role == "p1" else P1_ID
	match msg.get("type", ""):
		"sm_ping":
			emit_signal("received_ping", opponent_id, msg.get("payload", {}))
		"sm_ping_back":
			emit_signal("received_ping_back", opponent_id, msg.get("payload", {}))
		"sm_remote_start":
			emit_signal("received_remote_start")
		"sm_remote_stop":
			emit_signal("received_remote_stop")
		"sm_input_tick":
			var bytes: PoolByteArray = Marshalls.base64_to_raw(msg.get("data", ""))
			emit_signal("received_input_tick", opponent_id, bytes)

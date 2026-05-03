extends Node

# Autoload: persists custom control bindings across runs.
# Stores a JSON file in the user data directory mapping
# action_name -> [ serialized InputEvents ]

const CONFIG_PATH := "user://controls.cfg"

# Actions the player can rebind (P1 set).
# The P2 set is derived by replacing "p1_" prefix with "p2_".
const P1_ACTIONS := [
	"p1_left",
	"p1_right",
	"p1_jump",
	"p1_down",
	"p1_punch",
	"p1_kick",
	"p1_confirm",
]

const UI_ACTIONS := [
	"start",
	"pause",
]

var bindings: Dictionary = {}  # action_name -> Array of serialized events


func _ready() -> void:
	_load_bindings()


func _load_bindings() -> void:
	var file := File.new()
	if not file.file_exists(CONFIG_PATH):
		return

	file.open(CONFIG_PATH, File.READ)
	var text := file.get_as_text()
	file.close()

	var data: Dictionary = {}
	var err := JSON.parse(text)
	if err.error == OK:
		data = err.result as Dictionary

	# Apply each saved binding to the live InputMap
	for action in data:
		if not InputMap.has_action(action):
			continue
		var events_json: Array = data[action]
		# Clear existing events for this action (including defaults)
		for ev in InputMap.get_action_list(action):
			InputMap.action_erase_event(action, ev)
		# Re-add from saved data
		for ev_dict in events_json:
			var ev := _dict_to_event(ev_dict)
			if ev:
				InputMap.action_add_event(action, ev)

	bindings = data
	print("ControlsSave: loaded bindings for %d actions" % bindings.size())


func _save_bindings() -> void:
	var file := File.new()
	file.open(CONFIG_PATH, File.WRITE)
	file.store_string(JSON.print(bindings, "  "))
	file.close()
	print("ControlsSave: saved bindings for %d actions" % bindings.size())


func get_action_events(action: String) -> Array:
	# Return the current events for an action (live from InputMap).
	if not InputMap.has_action(action):
		return []
	return InputMap.get_action_list(action)


func save_action_events(action: String, events: Array) -> void:
	# Replace events for one action in both InputMap and our cache.
	if not InputMap.has_action(action):
		return

	# Clear current
	for ev in InputMap.get_action_list(action):
		InputMap.action_erase_event(action, ev)
	# Add new
	for ev in events:
		InputMap.action_add_event(action, ev)

	# Cache for persistence
	bindings[action] = _events_to_dicts(events)
	_save_bindings()


func get_all_rebindable_actions() -> Array:
	var actions := P1_ACTIONS.duplicate()
	actions.append_array(UI_ACTIONS)
	return actions


# --- Serialization helpers ---

func _events_to_dicts(events: Array) -> Array:
	var out := []
	for ev in events:
		out.append(_event_to_dict(ev))
	return out


func _event_to_dict(ev: InputEvent) -> Dictionary:
	var d := {}
	d["type"] = ev.get_class()
	if ev is InputEventKey:
		d["scancode"] = ev.scancode
		d["physical_scancode"] = ev.physical_scancode
		d["unicode"] = ev.unicode
	elif ev is InputEventJoypadButton:
		d["device"] = ev.device
		d["button_index"] = ev.button_index
	elif ev is InputEventJoypadMotion:
		d["device"] = ev.device
		d["axis"] = ev.axis
		d["axis_value"] = ev.axis_value
	return d


func _dict_to_event(d: Dictionary) -> InputEvent:
	match d.type:
		"InputEventKey":
			var ev := InputEventKey.new()
			ev.scancode = d.get("scancode", 0)
			ev.physical_scancode = d.get("physical_scancode", 0)
			ev.unicode = d.get("unicode", 0)
			return ev
		"InputEventJoypadButton":
			var ev := InputEventJoypadButton.new()
			ev.device = d.get("device", 0)
			ev.button_index = d.get("button_index", 0)
			return ev
		"InputEventJoypadMotion":
			var ev := InputEventJoypadMotion.new()
			ev.device = d.get("device", 0)
			ev.axis = d.get("axis", 0)
			ev.axis_value = d.get("axis_value", 0)
			return ev
	return null

extends Node

# Reads EmulationStation's es_input.cfg and remaps Godot's InputMap
# to match the physical buttons configured in RetroPie.
#
# Falls back silently to project defaults when:
#   - es_input.cfg does not exist (desktop / non-RetroPie)
#   - No connected joypad matches any config entry
#   - A required ES action is absent from the config

# ES action name -> list of [game_action, device_index] pairs to remap
const ACTION_MAP := {
	"left":            [["p1_left", 0],   ["p2_left", 1]],
	"right":           [["p1_right", 0],  ["p2_right", 1]],
	"up":              [["p1_jump", 0],   ["p2_jump", 1]],
	"leftanalogup":    [["p1_jump", 0],   ["p2_jump", 1]],
	"leftanalogleft":  [["p1_left", 0],   ["p2_left", 1]],
	"leftanalogright": [["p1_right", 0],  ["p2_right", 1]],
	"a":               [["p1_punch", 0],  ["p2_punch", 1],
	                    ["p1_confirm", 0],["p2_confirm", 1]],
	"b":               [["p1_kick", 0],   ["p2_kick", 1]],
	"start":           [["start", 0],     ["start", 1]],
	"select":          [["pause", 0],     ["pause", 1]],
}

# EmulationStation hat bitmask values -> Godot joypad button indices
const HAT_TO_BUTTON := {
	1: 12,  # up
	2: 14,  # right
	4: 15,  # down
	8: 13,  # left
}

# Candidate paths for es_input.cfg (checked in order)
const ES_CONFIG_PATHS := [
	"/home/pi/.emulationstation/es_input.cfg",
	"/root/.emulationstation/es_input.cfg",
	"/home/user/.emulationstation/es_input.cfg",
]


func _ready() -> void:
	var config_path := _find_config_file()
	if config_path == "":
		print("ControllerMapper: es_input.cfg not found, keeping default bindings")
		return

	print("ControllerMapper: loading ", config_path)
	var configs := _parse_es_config(config_path)
	if configs.empty():
		print("ControllerMapper: no valid inputConfig entries found")
		return

	# Remap each connected joypad (up to 2 players)
	for device in [0, 1]:
		var joy_guid: String = Input.get_joy_guid(device)
		var joy_name: String = Input.get_joy_name(device)
		if joy_guid == "" and joy_name == "":
			continue  # no controller on this slot

		var cfg = _find_matching_config(configs, joy_guid, joy_name)
		if cfg == null:
			print("ControllerMapper: no ES config match for device ", device,
				  " (", joy_name, " / ", joy_guid, "), keeping defaults")
			continue

		print("ControllerMapper: applying ES config for device ", device,
			  " matched to '", cfg.device_name, "'")
		_apply_config(cfg.inputs, device)


# --- Parsing ---

func _find_config_file() -> String:
	for path in ES_CONFIG_PATHS:
		if File.new().file_exists(path):
			return path
	return ""


# Returns Array of dicts: { device_name, device_guid, inputs: { es_name: {type, id, value} } }
func _parse_es_config(path: String) -> Array:
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		print("ControllerMapper: failed to open ", path)
		return []

	var configs := []
	var current_config = null

	while parser.read() == OK:
		var node_type := parser.get_node_type()

		if node_type == XMLParser.NODE_ELEMENT:
			var tag := parser.get_node_name()

			if tag == "inputConfig":
				current_config = {
					"device_name": _attr(parser, "deviceName", ""),
					"device_guid": _attr(parser, "deviceGUID", ""),
					"inputs": {},
				}

			elif tag == "input" and current_config != null:
				var name  := _attr(parser, "name", "")
				var itype := _attr(parser, "type", "")
				var id    := int(_attr(parser, "id", "0"))
				var value := int(_attr(parser, "value", "0"))
				if name != "" and itype != "":
					current_config.inputs[name] = {
						"type": itype, "id": id, "value": value
					}

		elif node_type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "inputConfig" and current_config != null:
				configs.append(current_config)
				current_config = null

	return configs


func _attr(parser: XMLParser, attr: String, default: String) -> String:
	for i in parser.get_attribute_count():
		if parser.get_attribute_name(i) == attr:
			return parser.get_attribute_value(i)
	return default


# --- Matching ---

func _find_matching_config(configs: Array, guid: String, name: String):
	# Prefer exact GUID match
	if guid != "":
		for cfg in configs:
			if cfg.device_guid == guid:
				return cfg
	# Fall back to device name substring match
	if name != "":
		for cfg in configs:
			if cfg.device_name.to_lower() in name.to_lower() or \
			   name.to_lower() in cfg.device_name.to_lower():
				return cfg
	return null


# --- Applying ---

func _apply_config(inputs: Dictionary, device: int) -> void:
	for es_action in ACTION_MAP:
		if not inputs.has(es_action):
			continue

		var info: Dictionary = inputs[es_action]
		var event = _make_event(info, device)
		if event == null:
			continue

		for binding in ACTION_MAP[es_action]:
			var game_action: String = binding[0]
			var target_device: int  = binding[1]
			if target_device != device:
				continue

			# Clone the event with the correct device index
			var ev = event.duplicate()
			ev.device = device
			_replace_joypad_event(game_action, ev)


func _make_event(info: Dictionary, device: int) -> InputEvent:
	match info.type:
		"button":
			var ev := InputEventJoypadButton.new()
			ev.device = device
			ev.button_index = info.id
			ev.pressed = true
			return ev

		"axis":
			var ev := InputEventJoypadMotion.new()
			ev.device = device
			ev.axis = info.id
			ev.axis_value = float(info.value)
			return ev

		"hat":
			# ES hat value is a bitmask; convert to Godot button index
			if not HAT_TO_BUTTON.has(info.value):
				print("ControllerMapper: unknown hat value ", info.value)
				return null
			var ev := InputEventJoypadButton.new()
			ev.device = device
			ev.button_index = HAT_TO_BUTTON[info.value]
			ev.pressed = true
			return ev

	return null


func _replace_joypad_event(action: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return

	# Remove existing joypad events for this device, keep keyboard events
	var to_remove := []
	for ev in InputMap.get_action_list(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			if ev.device == new_event.device:
				to_remove.append(ev)
	for ev in to_remove:
		InputMap.action_erase_event(action, ev)

	InputMap.action_add_event(action, new_event)
	print("ControllerMapper:  ", action, " device:", new_event.device,
		  " <- ", _describe_event(new_event))


func _describe_event(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton:
		return "button " + str(ev.button_index)
	if ev is InputEventJoypadMotion:
		return "axis " + str(ev.axis) + " value " + str(ev.axis_value)
	return "unknown"

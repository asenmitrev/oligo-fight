extends Control

# Controls binding menu. Shows every rebindable action, its current key/button,
# and lets the user navigate with arrow keys / controller D-pad and rebind
# by pressing any key while a row or button is highlighted.

var _controls_save = preload("res://scripts/controls_save.gd").new()
onready var _music: AudioStreamPlayer = $Music

var LOBSTER_FONT: BitmapFont = load("res://assets/fonts/lobster28.fnt")
var LOBSTER_FONT_SMALL: BitmapFont = load("res://assets/fonts/lobster20.fnt")

# Which player's bindings to show (0 = P1, 1 = P2)
var _player_index: int = 0
var _player_label: String = "Player 1"

# The list of action names for the current player
var _actions: Array = []

# Current editing row index (-1 = idle)
var _edit_row: int = -1

# Navigation state
# _focus_target: "row" or "button"
# _focus_index: which row (0..N-1) or which button (0=back, 1=P1, 2=P2)
var _focus_target: String = "button"
var _focus_index: int = 0  # start on Back button

# The VBox that holds action rows
var _vbox: VBoxContainer
# Subtitle label ("Player 1" / "Player 2") — needs to update on switch
var _subtitle: Label
# Array of [Label(action), Label(binding), Button(reset)] per row
var _rows: Array = []

# Bottom bar buttons
var _back_btn: Button
var _p1_btn: Button
var _p2_btn: Button
var _bottom_buttons: Array = []

# Highlight colors
const HIGHLIGHT_COLOR := Color(1, 0.88, 0.1, 1)
const NORMAL_BIND_COLOR := Color(0.7, 0.8, 1.0, 1)
const NORMAL_NAME_COLOR := Color.white


func _ready() -> void:
	_build_ui()
	_populate_actions()
	_build_rows()
	_apply_focus()

	var stream: AudioStream = preload("res://assets/music/character-select.ogg")
	stream.loop = true
	_music.stream = stream
	_music.play()


func _input(event: InputEvent) -> void:
	# If actively capturing a key for rebinding, route to capture handler
	if _edit_row >= 0:
		if _capture_input(event):
			return
		return

	# Start button goes back to main menu
	if event.is_action_pressed("start"):
		_on_back()
		return

	# --- Navigation ---
	if event.is_action_pressed("ui_up"):
		_navigate_up()
	elif event.is_action_pressed("ui_down"):
		_navigate_down()
	elif event.is_action_pressed("ui_left"):
		_navigate_left()
	elif event.is_action_pressed("ui_right"):
		_navigate_right()
	elif event.is_action_pressed("ui_accept"):
		_on_focus_accept()
	# Any other physical press while a row is focused -> rebind that action
	elif _focus_target == "row" and _focus_index >= 0 and event.pressed:
		_start_editing(_focus_index, _actions[_focus_index], _rows[_focus_index][1])


func _navigate_up() -> void:
	if _focus_target == "row":
		if _focus_index > 0:
			_focus_index -= 1
			_apply_focus()
		else:
			# Move focus to the bottom buttons (Back = index 0)
			_focus_target = "button"
			_focus_index = 0
			_apply_focus()
	elif _focus_target == "button":
		# Move into the row list — highlight last row
		_focus_target = "row"
		_focus_index = _actions.size() - 1
		_apply_focus()


func _navigate_down() -> void:
	if _focus_target == "row":
		if _focus_index < _actions.size() - 1:
			_focus_index += 1
			_apply_focus()
		else:
			# Move focus to the bottom buttons
			_focus_target = "button"
			_focus_index = 0
			_apply_focus()
	elif _focus_target == "button":
		# Move into the row list — highlight first row
		_focus_target = "row"
		_focus_index = 0
		_apply_focus()


func _navigate_left() -> void:
	if _focus_target == "button":
		_focus_index = (_focus_index - 1 + _bottom_buttons.size()) % _bottom_buttons.size()
		_apply_focus()


func _navigate_right() -> void:
	if _focus_target == "button":
		_focus_index = (_focus_index + 1) % _bottom_buttons.size()
		_apply_focus()


func _on_focus_accept() -> void:
	if _focus_target == "row" and _focus_index >= 0:
		var action: String = _actions[_focus_index]
		var lbl: Label = _rows[_focus_index][1]
		_start_editing(_focus_index, action, lbl)
	elif _focus_target == "button":
		match _focus_index:
			0: _on_back()
			1: _switch_to_p1()
			2: _switch_to_p2()


func _apply_focus() -> void:
	# Clear all highlights
	for i in range(_rows.size()):
		_rows[i][0].add_color_override("font_color", NORMAL_NAME_COLOR)
		_rows[i][1].add_color_override("font_color", NORMAL_BIND_COLOR)
		_rows[i][2].modulate = Color.white

		for btn in _bottom_buttons:
			btn.modulate = Color.white

	# Apply highlight
	if _focus_target == "row" and _focus_index >= 0 and _focus_index < _rows.size():
		_rows[_focus_index][0].add_color_override("font_color", HIGHLIGHT_COLOR)
		_rows[_focus_index][1].add_color_override("font_color", HIGHLIGHT_COLOR)
		_rows[_focus_index][2].modulate = HIGHLIGHT_COLOR
		# Scroll the row into view
		_scroll_to_row(_focus_index)
	elif _focus_target == "button" and _focus_index >= 0 and _focus_index < _bottom_buttons.size():
		_bottom_buttons[_focus_index].modulate = HIGHLIGHT_COLOR


func _scroll_to_row(row_idx: int) -> void:
	# Ensure the focused row is visible within the ScrollContainer
	var scroll: ScrollContainer = _vbox.get_parent()
	var row_control: Control = _vbox.get_child(row_idx)
	var row_global_pos := row_control.get_global_rect().position.y
	var scroll_global_pos := scroll.get_global_rect().position.y
	var relative_pos := row_global_pos - scroll_global_pos
	var scroll_height := scroll.get_rect().size.y
	if relative_pos < 0:
		scroll.scroll_v -= relative_pos
	elif relative_pos > scroll_height:
		scroll.scroll_v += relative_pos - scroll_height


func _build_ui() -> void:
	var vp := get_viewport().size

	# Dark background
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.04, 0.04, 0.08, 1.0)
	add_child(bg)

	# Background art
	var bg_tex := TextureRect.new()
	bg_tex.texture = load("res://assets/bg_character-select.png")
	bg_tex.expand = true
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.anchor_right = 1.0
	bg_tex.anchor_bottom = 1.0
	bg_tex.modulate.a = 0.35
	add_child(bg_tex)

	# Title
	var title := Label.new()
	title.text = "CONTROLS"
	title.add_font_override("font", LOBSTER_FONT)
	title.add_color_override("font_color", Color(1, 0.88, 0.1, 1))
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	title.margin_top = vp.y * 0.02
	title.margin_bottom = vp.y * 0.02 + 50
	title.align = Label.ALIGN_CENTER
	add_child(title)

	# Subtitle showing which player
	_subtitle = Label.new()
	_subtitle.text = _player_label
	_subtitle.add_font_override("font", LOBSTER_FONT_SMALL)
	_subtitle.add_color_override("font_color", Color(0.8, 0.8, 0.9, 1))
	_subtitle.anchor_left = 0.0
	_subtitle.anchor_right = 1.0
	_subtitle.anchor_top = 0.0
	_subtitle.anchor_bottom = 0.0
	_subtitle.margin_top = vp.y * 0.02 + 55
	_subtitle.margin_bottom = vp.y * 0.02 + 55 + 28
	_subtitle.align = Label.ALIGN_CENTER
	add_child(_subtitle)

	# Scroll container with VBox inside
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.05
	scroll.anchor_right = 0.95
	scroll.anchor_top = 0.18
	scroll.anchor_bottom = 0.82
	scroll.scroll_horizontal = false
	add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_constant_override("separation", 4)
	scroll.add_child(_vbox)

	# Bottom bar: Back + Player switch buttons
	var hbox := HBoxContainer.new()
	hbox.anchor_left = 0.15
	hbox.anchor_right = 0.85
	hbox.anchor_top = 0.85
	hbox.anchor_bottom = 0.85
	hbox.add_constant_override("separation", 16)
	add_child(hbox)

	_back_btn = _make_button("Back")
	_back_btn.connect("pressed", self, "_on_back")
	hbox.add_child(_back_btn)
	_bottom_buttons.append(_back_btn)

	_p1_btn = _make_button("P1")
	_p1_btn.connect("pressed", self, "_switch_to_p1")
	hbox.add_child(_p1_btn)
	_bottom_buttons.append(_p1_btn)

	_p2_btn = _make_button("P2")
	_p2_btn.connect("pressed", self, "_switch_to_p2")
	hbox.add_child(_p2_btn)
	_bottom_buttons.append(_p2_btn)


func _populate_actions() -> void:
	_actions.clear()
	if _player_index == 0:
		for a in ControlsSave.P1_ACTIONS:
			_actions.append(a)
	else:
		for a in ControlsSave.P1_ACTIONS:
			_actions.append(a.replace("p1_", "p2_"))


func _build_rows() -> void:
	# Clear old rows
	for row_data in _rows:
		for child in row_data:
			child.queue_free()
	_rows.clear()
	for child in _vbox.get_children():
		child.queue_free()

	for i in range(_actions.size()):
		var action: String = _actions[i]
		var row := HBoxContainer.new()
		row.rect_min_size = Vector2(0, 28)
		row.add_constant_override("separation", 8)

		# Action name label
		var name_lbl := Label.new()
		name_lbl.text = _prettify_action(action)
		name_lbl.add_font_override("font", LOBSTER_FONT_SMALL)
		name_lbl.add_color_override("font_color", NORMAL_NAME_COLOR)
		name_lbl.rect_min_size = Vector2(120, 0)
		row.add_child(name_lbl)

		# Binding label (clickable to rebind)
		var bind_lbl := Label.new()
		bind_lbl.text = _describe_binding(action)
		bind_lbl.add_font_override("font", LOBSTER_FONT_SMALL)
		bind_lbl.add_color_override("font_color", NORMAL_BIND_COLOR)
		bind_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		bind_lbl.size_flags_horizontal = Control.SIZE_FILL
		bind_lbl.connect("gui_input", self, "_on_binding_click", [i, action, bind_lbl])
		row.add_child(bind_lbl)

		# Reset button
		var reset_btn := Button.new()
		reset_btn.text = "Reset"
		reset_btn.add_font_override("font", LOBSTER_FONT_SMALL)
		reset_btn.rect_min_size = Vector2(50, 0)
		reset_btn.connect("pressed", self, "_on_reset", [action])
		row.add_child(reset_btn)

		_vbox.add_child(row)
		_rows.append([name_lbl, bind_lbl, reset_btn])


func _prettify_action(action: String) -> String:
	var name := action.replace("p1_", "").replace("p2_", "")
	return name.capitalize()


func _describe_binding(action: String) -> String:
	var events = ControlsSave.get_action_events(action)
	if events.empty():
		return "(none)"
	var parts := []
	for ev in events:
		parts.append(_describe_event(ev))
	return ", ".join(parts)


func _describe_event(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var key_label: String = OS.get_scancode_string(ev.scancode)
		if key_label == "":
			key_label = "scancode:%d" % ev.scancode
		return key_label
	elif ev is InputEventJoypadButton:
		return "Joy Btn %d" % ev.button_index
	elif ev is InputEventJoypadMotion:
		var axis_name := ""
		match ev.axis:
			0: axis_name = "L-Stick X"
			1: axis_name = "L-Stick Y"
			2: axis_name = "R-Stick X"
			3: axis_name = "R-Stick Y"
		return "%s (val %.0f)" % [axis_name, ev.axis_value]
	return "???"


func _on_binding_click(event: InputEvent, row_idx: int, action: String, lbl: Label) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		# Mouse click: shift focus to this row and start editing
		_focus_target = "row"
		_focus_index = row_idx
		_apply_focus()
		_start_editing(row_idx, action, lbl)
	elif event.is_action_pressed("ui_accept"):
		_start_editing(row_idx, action, lbl)


func _start_editing(row_idx: int, action: String, lbl: Label) -> void:
	_edit_row = row_idx

	# Highlight the label
	lbl.add_color_override("font_color", HIGHLIGHT_COLOR)
	lbl.text = "Press any key..."


func _capture_input(event: InputEvent) -> bool:
	# Returns true if the event was consumed (binding applied)
	if _edit_row < 0:
		return false

	# Only accept physical presses (not repeats, not releases).
	# InputEventJoypadMotion has no `pressed` field, so use is_pressed() which
	# is virtual on InputEvent and returns abs(axis_value) >= 0.5 for motion.
	if not event.is_pressed():
		return false

	var action: String = _actions[_edit_row]
	var lbl: Label = _rows[_edit_row][1]

	# During capture, skip modifier-only keys
	if event is InputEventKey:
		if event.scancode in [KEY_ALT, KEY_SHIFT, KEY_CONTROL, KEY_META]:
			return false
		_finish_editing(action, event, lbl)
		return true

	if event is InputEventJoypadButton:
		_finish_editing(action, event, lbl)
		return true

	if event is InputEventJoypadMotion:
		if abs(event.axis_value) >= 0.5:
			_finish_editing(action, event, lbl)
			return true

	return false


func _finish_editing(action: String, new_event: InputEvent, lbl: Label) -> void:
	_edit_row = -1

	# Replace events for this action
	var events := [new_event]
	ControlsSave.save_action_events(action, events)

	# Update display
	lbl.text = _describe_event(new_event)
	# Re-apply focus highlighting (which also resets colors)
	_apply_focus()


func _on_reset(action: String) -> void:
	# Erase custom events; project.godot defaults remain in InputMap at runtime
	# so we re-add the defaults from the project config.
	# For simplicity, just clear the saved override.
	if ControlsSave.bindings.has(action):
		ControlsSave.bindings.erase(action)
		ControlsSave._save_bindings()
	_build_rows()
	_apply_focus()


func _on_back() -> void:
	_music.stop()
	get_tree().change_scene("res://scenes/MainMenu.tscn")


func _switch_to_p1() -> void:
	_player_index = 0
	_player_label = "Player 1"
	_subtitle.text = _player_label
	_populate_actions()
	_build_rows()
	_focus_target = "button"
	_focus_index = 1
	_apply_focus()


func _switch_to_p2() -> void:
	_player_index = 1
	_player_label = "Player 2"
	_subtitle.text = _player_label
	_populate_actions()
	_build_rows()
	_focus_target = "button"
	_focus_index = 2
	_apply_focus()


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_font_override("font", LOBSTER_FONT_SMALL)
	btn.rect_min_size = Vector2(0, 36)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	normal.border_color = Color(0.4, 0.4, 0.7)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	btn.add_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.2, 0.45, 0.95)
	hover.border_color = Color(0.8, 0.8, 1.0)
	btn.add_stylebox_override("hover", hover)
	btn.add_stylebox_override("focus", hover)

	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.05, 0.05, 0.15, 1.0)
	btn.add_stylebox_override("pressed", pressed_style)

	return btn

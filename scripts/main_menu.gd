extends Control

onready var _music: AudioStreamPlayer = $Music

var LOBSTER_FONT: BitmapFont = load("res://assets/fonts/lobster52.fnt")
var LOBSTER_FONT_28: BitmapFont = load("res://assets/fonts/lobster28.fnt")

var _menu_buttons: Array = []  # Buttons navigable by arrow keys / joystick
var _selected_index: int = 0


func _ready() -> void:
	_build_ui()

	var stream: AudioStream = preload("res://assets/music/character-select.ogg")
	stream.loop = true
	_music.stream = stream
	_music.play()


func _input(event: InputEvent) -> void:
	# Arrow keys / joystick D-pad / joystick hat to navigate
	if event.is_action_pressed("ui_down"):
		_selected_index = (_selected_index + OsUtil.reverse_direction(1) + _menu_buttons.size()) % _menu_buttons.size()
		_set_selected(_selected_index)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_selected_index = (_selected_index + OsUtil.reverse_direction(-1) + _menu_buttons.size()) % _menu_buttons.size()
		_set_selected(_selected_index)
		get_viewport().set_input_as_handled()
		return

	# ui_accept (Enter / A button) activates the selected button
	if event.is_action_pressed("ui_accept"):
		if _menu_buttons.size() > 0:
			_menu_buttons[_selected_index].emit_signal("pressed")
		get_viewport().set_input_as_handled()
		return

	# Start button goes straight to character select
	if event.is_action_pressed("start"):
		_on_local_play()


func _set_selected(index: int) -> void:
	for i in range(_menu_buttons.size()):
		var btn: Button = _menu_buttons[i]
		if i == index:
			btn.grab_focus()
			btn.modulate = Color(1, 0.88, 0.1, 1)  # Gold highlight
		else:
			btn.modulate = Color(1, 1, 1, 1)  # Normal white


func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.04, 0.04, 0.08, 1.0)
	add_child(bg)

	# Background art (reuse the character select splash)
	var bg_tex := TextureRect.new()
	bg_tex.texture = load("res://assets/bg_character-select.png")
	bg_tex.expand = true
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.anchor_right = 1.0
	bg_tex.anchor_bottom = 1.0
	bg_tex.modulate.a = 0.35
	add_child(bg_tex)

	# Title — anchor-based, stays at top-center regardless of screen size
	var title := Label.new()
	title.text = "OLIGO FIGHT"
	title.add_font_override("font", LOBSTER_FONT)
	title.add_color_override("font_color", Color(1, 0.88, 0.1, 1))
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.08
	title.anchor_bottom = 0.22
	title.align = Label.ALIGN_CENTER
	add_child(title)

	# Buttons wrapped in a VBoxContainer, perfectly centered
	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.35
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.55
	vbox.margin_left = -130.0   # -(btn_width / 2)
	vbox.margin_right = 130.0   # +(btn_width / 2)
	vbox.add_constant_override("separation", 16)
	add_child(vbox)

	var btn_width := 260.0
	var btn_height := 56.0

	# Local Play button
	var play_btn := _make_button("Local Play")
	play_btn.rect_min_size = Vector2(btn_width, btn_height)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.connect("pressed", self, "_on_local_play")
	vbox.add_child(play_btn)
	_menu_buttons.append(play_btn)

	var controls_btn := _make_button("Controls")
	controls_btn.rect_min_size = Vector2(btn_width, btn_height)
	controls_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	controls_btn.connect("pressed", self, "_on_controls")
	vbox.add_child(controls_btn)
	_menu_buttons.append(controls_btn)

	var quit_btn := _make_button("Quit")
	quit_btn.rect_min_size = Vector2(btn_width, btn_height)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_btn.connect("pressed", self, "_on_quit")
	vbox.add_child(quit_btn)
	_menu_buttons.append(quit_btn)

	# Select first button
	_set_selected(0)




func _on_local_play() -> void:
	_music.stop()
	get_tree().change_scene("res://scenes/CharacterSelect.tscn")


func _on_controls() -> void:
	_music.stop()
	get_tree().change_scene("res://scenes/ControlsMenu.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_font_override("font", LOBSTER_FONT_28)
	btn.rect_min_size = Vector2(0, 48)

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

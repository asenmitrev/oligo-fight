extends Control

onready var _music: AudioStreamPlayer = $Music

var LOBSTER_FONT: BitmapFont = load("res://assets/fonts/lobster52.fnt")
var LOBSTER_FONT_28: BitmapFont = load("res://assets/fonts/lobster28.fnt")


func _ready() -> void:
	if OS.get_name() == "X11":
		_on_local_play()
		return

	_build_ui()

	var stream: AudioStream = preload("res://assets/music/character-select.ogg")
	stream.loop = true
	_music.stream = stream
	_music.play()


func _input(event: InputEvent) -> void:
	# Start button goes straight to character select
	if event.is_action_pressed("start"):
		_on_local_play()


func _build_ui() -> void:
	var vp := get_viewport().size

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

	# Title
	var title := Label.new()
	title.text = "OLIGO FIGHT"
	title.add_font_override("font", LOBSTER_FONT)
	title.add_color_override("font_color", Color(1, 0.88, 0.1, 1))
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	title.margin_top = vp.y * 0.18
	title.margin_bottom = vp.y * 0.18 + 70
	title.align = Label.ALIGN_CENTER
	add_child(title)

	# Menu buttons: Controls and Quit, centered below title
	var btn_y := vp.y * 0.32
	var btn_width := 260.0
	var btn_height := 56.0
	var gap := 16.0

	var controls_btn := _make_button("Controls")
	controls_btn.rect_size = Vector2(btn_width, btn_height)
	controls_btn.rect_position = Vector2((vp.x - btn_width) / 2.0, btn_y)
	controls_btn.connect("pressed", self, "_on_controls")
	add_child(controls_btn)

	var quit_btn := _make_button("Quit")
	quit_btn.rect_size = Vector2(btn_width, btn_height)
	quit_btn.rect_position = Vector2((vp.x - btn_width) / 2.0, btn_y + btn_height + gap)
	quit_btn.connect("pressed", self, "_on_quit")
	add_child(quit_btn)

	# Start hint (smaller, below buttons)
	var start_hint := Label.new()
	start_hint.text = "Press START to play"
	start_hint.add_font_override("font", LOBSTER_FONT_28)
	start_hint.add_color_override("font_color", Color(0.5, 0.5, 0.6, 1))
	start_hint.anchor_left = 0.0
	start_hint.anchor_right = 1.0
	start_hint.anchor_top = 0.0
	start_hint.anchor_bottom = 0.0
	start_hint.margin_top = btn_y + btn_height * 2 + gap + 12
	start_hint.margin_bottom = btn_y + btn_height * 2 + gap + 12 + 24
	start_hint.align = Label.ALIGN_CENTER
	add_child(start_hint)


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

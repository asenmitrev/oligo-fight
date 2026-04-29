extends Control

onready var _music: AudioStreamPlayer = $Music

var _local_btn: Button

# Shared font data — created once, reused for title + buttons (saves RAM on Pi 3)
var _lobster_font_data: DynamicFontData

func _get_lobster_font_data() -> DynamicFontData:
	if not _lobster_font_data:
		_lobster_font_data = DynamicFontData.new()
		_lobster_font_data.font_path = "res://assets/fonts/Lobster-Regular.ttf"
	return _lobster_font_data


func _ready() -> void:
	if OS.get_name() == "X11":
		_on_local_play()
		return

	_build_ui()

	var stream := load("res://assets/music/character-select.ogg") as AudioStream
	stream.loop = true
	_music.stream = stream
	_music.play()


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
	var title_font := DynamicFont.new()
	title_font.font_data = _get_lobster_font_data()
	title_font.size = 52
	title_font.outline_size = 6
	title_font.outline_color = Color(0, 0, 0, 1)

	var title := Label.new()
	title.text = "OLIGO FIGHT"
	title.add_font_override("font", title_font)
	title.add_color_override("font_color", Color(1, 0.88, 0.1, 1))
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	title.margin_top = vp.y * 0.18
	title.margin_bottom = vp.y * 0.18 + 70
	title.align = Label.ALIGN_CENTER
	add_child(title)

	# Button font
	var btn_font := DynamicFont.new()
	btn_font.font_data = _get_lobster_font_data()
	btn_font.size = 24
	btn_font.outline_size = 3
	btn_font.outline_color = Color(0, 0, 0, 1)

	# VBox for buttons
	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.3
	vbox.anchor_right = 0.7
	vbox.anchor_top = 0.55
	vbox.anchor_bottom = 0.55
	vbox.add_constant_override("separation", 16)
	add_child(vbox)

	_local_btn = _make_button("Play", btn_font)
	_local_btn.connect("pressed", self, "_on_local_play")
	vbox.add_child(_local_btn)

	_local_btn.call_deferred("grab_focus")


func _make_button(text: String, font: DynamicFont) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_font_override("font", font)
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


func _on_local_play() -> void:
	_music.stop()
	get_tree().change_scene("res://scenes/CharacterSelect.tscn")

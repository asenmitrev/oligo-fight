extends Control

var _status_label: Label
var _detail_label: Label
var _cancel_btn: Button
var _connecting: bool = false


func _ready() -> void:
	_build_ui()
	_set_status("Connecting...", "")
	_connect_signals()
	NetworkManager.connect_to_server()


func _build_ui() -> void:
	var vp := get_viewport().size

	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.04, 0.04, 0.08, 1.0)
	add_child(bg)

	var bg_tex := TextureRect.new()
	bg_tex.texture = load("res://assets/bg_character-select.png")
	bg_tex.expand = true
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.anchor_right = 1.0
	bg_tex.anchor_bottom = 1.0
	bg_tex.modulate.a = 0.25
	add_child(bg_tex)

	var font_data := DynamicFontData.new()
	font_data.font_path = "res://assets/fonts/Lobster-Regular.ttf"

	var title_font := DynamicFont.new()
	title_font.font_data = font_data
	title_font.size = 36
	title_font.outline_size = 5
	title_font.outline_color = Color(0, 0, 0, 1)

	var title := Label.new()
	title.text = "ONLINE"
	title.add_font_override("font", title_font)
	title.add_color_override("font_color", Color(1, 0.88, 0.1, 1))
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.margin_top = vp.y * 0.18
	title.margin_bottom = vp.y * 0.18 + 50
	title.align = Label.ALIGN_CENTER
	add_child(title)

	var status_font := DynamicFont.new()
	status_font.font_data = font_data
	status_font.size = 22
	status_font.outline_size = 3
	status_font.outline_color = Color(0, 0, 0, 1)

	_status_label = Label.new()
	_status_label.add_font_override("font", status_font)
	_status_label.add_color_override("font_color", Color.white)
	_status_label.anchor_left = 0.0
	_status_label.anchor_right = 1.0
	_status_label.margin_top = vp.y * 0.45
	_status_label.margin_bottom = vp.y * 0.45 + 36
	_status_label.align = Label.ALIGN_CENTER
	add_child(_status_label)

	var detail_font := DynamicFont.new()
	detail_font.font_data = font_data
	detail_font.size = 14
	detail_font.outline_size = 2
	detail_font.outline_color = Color(0, 0, 0, 1)

	_detail_label = Label.new()
	_detail_label.add_font_override("font", detail_font)
	_detail_label.add_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	_detail_label.anchor_left = 0.0
	_detail_label.anchor_right = 1.0
	_detail_label.margin_top = vp.y * 0.56
	_detail_label.margin_bottom = vp.y * 0.56 + 24
	_detail_label.align = Label.ALIGN_CENTER
	add_child(_detail_label)

	var cancel_font := DynamicFont.new()
	cancel_font.font_data = font_data
	cancel_font.size = 16
	cancel_font.outline_size = 2
	cancel_font.outline_color = Color(0, 0, 0, 1)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.add_font_override("font", cancel_font)
	_cancel_btn.rect_min_size = Vector2(120, 36)
	_cancel_btn.anchor_left = 0.5
	_cancel_btn.anchor_right = 0.5
	_cancel_btn.anchor_top = 0.75
	_cancel_btn.anchor_bottom = 0.75
	_cancel_btn.margin_left = -60
	_cancel_btn.margin_right = 60
	_cancel_btn.margin_top = 0
	_cancel_btn.margin_bottom = 36
	_cancel_btn.connect("pressed", self, "_on_cancel")
	add_child(_cancel_btn)
	_cancel_btn.call_deferred("grab_focus")


func _connect_signals() -> void:
	NetworkManager.connect("matched", self, "_on_matched")


func _set_status(status: String, detail: String) -> void:
	if _status_label:
		_status_label.text = status
	if _detail_label:
		_detail_label.text = detail


func _on_matched(role: String) -> void:
	_set_status("Opponent found!", "Entering character select...")
	yield(get_tree().create_timer(0.8), "timeout")
	get_tree().change_scene("res://scenes/CharacterSelect.tscn")


func _on_cancel() -> void:
	NetworkManager.disconnect_from_server()
	GameState.is_online = false
	get_tree().change_scene("res://scenes/MainMenu.tscn")


func _process(_delta: float) -> void:
	# Animate the "..." in the status text
	if NetworkManager._state == "in_queue":
		var dots := int(OS.get_ticks_msec() / 500) % 4
		_set_status("Finding opponent" + ".".repeat(dots), "Waiting for another player to connect")
	elif NetworkManager._state == "connecting":
		var dots := int(OS.get_ticks_msec() / 500) % 4
		_set_status("Connecting" + ".".repeat(dots), "")

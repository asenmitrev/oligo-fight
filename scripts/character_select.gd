extends Control

var p1_index := 0
var p2_index := 1
var p1_confirmed := false
var p2_confirmed := false

const UI_TEXT_SCALE := 1.55
const PREVIEW_SCALE := 1.80
const SLOT_WIDTH := 256
const PREVIEW_OFFSET := Vector2(0, -25)
const FEET_FROM_BOTTOM := 50  # px from bottom of screen where character feet sit
const BORDER_WIDTH_NORMAL := 5
const BORDER_WIDTH_CONFIRMED := 12
const P2_BORDER_INSET := 7  # P2 border is drawn inset inside P1's border

onready var P1_COLOR := GameState.P1_COLOR
onready var P2_COLOR := GameState.P2_COLOR

var char_slots: Array = []
var char_previews: Array = []
var p1_borders: Array = []
var p2_borders: Array = []

var _pause_menu: CanvasLayer
var _resume_btn: Button
var _quit_btn: Button
var _is_paused: bool = false

onready var select_grid: Control = $SelectGrid
onready var p1_tween: Tween = Tween.new()
onready var p2_tween: Tween = Tween.new()
onready var _music: AudioStreamPlayer = $Music


func _ready() -> void:
	add_child(p1_tween)
	add_child(p2_tween)
	_setup_select_grid()
	_build_pause_menu()
	call_deferred("_apply_ui_text_scale")
	_update_ui()

	var stream := load("res://assets/music/character-select.mp3") as AudioStreamMP3
	stream.loop = true
	_music.stream = stream
	_music.play()


func _make_lobster_font(size: int) -> DynamicFont:
	var data := DynamicFontData.new()
	data.font_path = "res://assets/fonts/Lobster-Regular.ttf"
	var font := DynamicFont.new()
	font.font_data = data
	font.size = size
	font.outline_size = 4
	font.outline_color = Color(0, 0, 0, 1)
	return font


func _setup_select_grid() -> void:
	var vp := get_viewport().size
	var sprite_y := vp.y - FEET_FROM_BOTTOM
	# one center-x per character — add an entry here if you add a character
	var centers_x := [vp.x * 0.2, vp.x * 0.5, vp.x * 0.8]
	assert(CharacterDB.all_characters.size() == centers_x.size(), "centers_x needs one entry per character")

	for i in range(CharacterDB.all_characters.size()):
		var char_def = CharacterDB.all_characters[i]

		var slot := Control.new()
		slot.rect_position = Vector2(centers_x[i] - SLOT_WIDTH / 2.0, sprite_y - SLOT_WIDTH)
		slot.rect_size = Vector2(SLOT_WIDTH, SLOT_WIDTH + 34)
		select_grid.add_child(slot)
		char_slots.append(slot)

		var p1_b := _make_border_panel(P1_COLOR, Vector2.ZERO, Vector2(SLOT_WIDTH, SLOT_WIDTH))
		slot.add_child(p1_b)
		p1_borders.append(p1_b)

		var ins := P2_BORDER_INSET
		var p2_b := _make_border_panel(P2_COLOR, Vector2(ins, ins), Vector2(SLOT_WIDTH - ins * 2, SLOT_WIDTH - ins * 2))
		slot.add_child(p2_b)
		p2_borders.append(p2_b)

		var preview := AnimatedSprite.new()
		preview.position = Vector2(SLOT_WIDTH / 2.0, SLOT_WIDTH)
		preview.offset = PREVIEW_OFFSET
		var ps := PREVIEW_SCALE * char_def.sprite_scale
		preview.scale = Vector2(ps, ps)
		preview.flip_h = (i == 1)
		preview.frames = char_def.get_preview_sprite_frames()
		preview.play("idle")
		slot.add_child(preview)
		char_previews.append(preview)

		var name_lbl := Label.new()
		name_lbl.rect_position = Vector2(0, SLOT_WIDTH + 4)
		name_lbl.rect_size = Vector2(SLOT_WIDTH, 30)
		name_lbl.align = Label.ALIGN_CENTER
		name_lbl.text = char_def.display_name
		name_lbl.add_font_override("font", _make_lobster_font(16))
		name_lbl.add_color_override("font_color", Color.white)
		slot.add_child(name_lbl)


func _make_border_panel(color: Color, pos: Vector2, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.rect_position = pos
	panel.rect_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	_set_border_width(style, BORDER_WIDTH_NORMAL)
	panel.add_stylebox_override("panel", style)
	panel.visible = false
	return panel


func _set_border_width(style: StyleBoxFlat, width: int) -> void:
	style.border_width_left = width
	style.border_width_right = width
	style.border_width_top = width
	style.border_width_bottom = width


func _apply_ui_text_scale() -> void:
	var title: Label = $Title
	title.add_font_override("font", _make_lobster_font(16))
	title.add_color_override("font_color", Color.white)
	title.rect_pivot_offset = title.rect_size / 2.0
	title.rect_scale = Vector2(UI_TEXT_SCALE, UI_TEXT_SCALE)

	var vs: Label = $VSLabel
	vs.modulate = Color.white  # clear scene modulate; font_color handles the tint
	vs.add_font_override("font", _make_lobster_font(28))
	vs.add_color_override("font_color", Color(1, 0.85, 0.1, 1))
	vs.rect_pivot_offset = vs.rect_size / 2.0
	vs.rect_scale = Vector2(UI_TEXT_SCALE, UI_TEXT_SCALE)


func _build_pause_menu() -> void:
	_pause_menu = CanvasLayer.new()
	_pause_menu.layer = 20
	add_child(_pause_menu)

	var bg = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_menu.add_child(bg)

	var panel = ColorRect.new()
	panel.color = Color(0.1, 0.1, 0.15, 0.95)
	panel.anchor_left = 0.35
	panel.anchor_right = 0.65
	panel.anchor_top = 0.25
	panel.anchor_bottom = 0.75
	bg.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.margin_left = 20
	vbox.margin_right = -20
	vbox.margin_top = 20
	vbox.margin_bottom = -20
	vbox.add_constant_override("separation", 24)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "PAUSED"
	title.align = Label.ALIGN_CENTER
	vbox.add_child(title)

	_resume_btn = Button.new()
	_resume_btn.text = "Resume"
	_resume_btn.connect("pressed", self, "_resume_game")
	vbox.add_child(_resume_btn)

	_quit_btn = Button.new()
	_quit_btn.text = "Quit Game"
	_quit_btn.connect("pressed", self, "_on_pause_quit")
	vbox.add_child(_quit_btn)

	_resume_btn.focus_neighbour_bottom = _resume_btn.get_path_to(_quit_btn)
	_resume_btn.focus_neighbour_top = _resume_btn.get_path_to(_quit_btn)
	_quit_btn.focus_neighbour_bottom = _quit_btn.get_path_to(_resume_btn)
	_quit_btn.focus_neighbour_top = _quit_btn.get_path_to(_resume_btn)

	_pause_menu.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _is_paused:
			_resume_game()
		else:
			_pause_game()


func _pause_game() -> void:
	_is_paused = true
	_pause_menu.visible = true
	_resume_btn.call_deferred("grab_focus")
	_music.stream_paused = true


func _resume_game() -> void:
	_is_paused = false
	_pause_menu.visible = false
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	_music.stream_paused = false


func _on_pause_quit() -> void:
	_music.stop()
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _is_paused:
		if event.is_action_pressed("ui_cancel") and not event.is_action_pressed("pause"):
			_resume_game()
			get_viewport().set_input_as_handled()
		return

	var num := CharacterDB.all_characters.size()

	if not p1_confirmed:
		if event.is_action_pressed("p1_left"):
			p1_index = (p1_index - 1 + num) % num
			_update_ui()
			_flash_selection(p1_borders[p1_index], P1_COLOR, p1_tween)
		elif event.is_action_pressed("p1_right"):
			p1_index = (p1_index + 1) % num
			_update_ui()
			_flash_selection(p1_borders[p1_index], P1_COLOR, p1_tween)
		elif event.is_action_pressed("p1_confirm"):
			p1_confirmed = true
			_update_ui()
			_set_border_width(p1_borders[p1_index].get_stylebox("panel"), BORDER_WIDTH_CONFIRMED)
			_flash_selection(p1_borders[p1_index], P1_COLOR, p1_tween, true)
			_check_start()
	elif event.is_action_pressed("p1_confirm") and not p2_confirmed:
		p1_confirmed = false
		_update_ui()
		_set_border_width(p1_borders[p1_index].get_stylebox("panel"), BORDER_WIDTH_NORMAL)

	if not p2_confirmed:
		if event.is_action_pressed("p2_left"):
			p2_index = (p2_index - 1 + num) % num
			_update_ui()
			_flash_selection(p2_borders[p2_index], P2_COLOR, p2_tween)
		elif event.is_action_pressed("p2_right"):
			p2_index = (p2_index + 1) % num
			_update_ui()
			_flash_selection(p2_borders[p2_index], P2_COLOR, p2_tween)
		elif event.is_action_pressed("p2_confirm"):
			p2_confirmed = true
			_update_ui()
			_set_border_width(p2_borders[p2_index].get_stylebox("panel"), BORDER_WIDTH_CONFIRMED)
			_flash_selection(p2_borders[p2_index], P2_COLOR, p2_tween, true)
			_check_start()
	elif event.is_action_pressed("p2_confirm") and not p1_confirmed:
		p2_confirmed = false
		_update_ui()
		_set_border_width(p2_borders[p2_index].get_stylebox("panel"), BORDER_WIDTH_NORMAL)


func _update_ui() -> void:
	for i in range(char_slots.size()):
		p1_borders[i].visible = (p1_index == i)
		p2_borders[i].visible = (p2_index == i)


func _flash_selection(panel: Panel, color: Color, tween: Tween, is_confirm: bool = false) -> void:
	var style: StyleBoxFlat = panel.get_stylebox("panel")
	tween.stop_all()
	var flash_color := color
	flash_color.a = 0.7 if is_confirm else 0.3
	var duration := 0.5 if is_confirm else 0.2
	tween.interpolate_property(style, "bg_color", flash_color, Color(0, 0, 0, 0), duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(style, "border_color", Color.white, color, duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()


func _check_start() -> void:
	if p1_confirmed and p2_confirmed:
		var p1_def = CharacterDB.all_characters[p1_index]
		var p2_def = CharacterDB.all_characters[p2_index]
		GameState.p1_character = p1_def.display_name
		GameState.p2_character = p2_def.display_name
		GameState.p2_is_mirror = (p1_index == p2_index)
		_show_fight_sequence()


func _show_fight_sequence() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)

	# Full-screen Control for anchor-based child positioning
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	overlay.add_child(root)

	# Dim backdrop
	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.82)
	root.add_child(dim)

	# fight-text.png — 320px wide (50% of 640), centered, upper-center of screen.
	# Box is 320x110; STRETCH_KEEP_ASPECT_CENTERED fills it without distortion.
	var fight_tex := TextureRect.new()
	fight_tex.texture = load("res://assets/fight-text.png")
	fight_tex.expand = true
	fight_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fight_tex.anchor_left = 0.5
	fight_tex.anchor_right = 0.5
	fight_tex.anchor_top = 0.5
	fight_tex.anchor_bottom = 0.5
	fight_tex.rect_size = Vector2(320, 110)
	fight_tex.margin_left = -160.0
	fight_tex.margin_right = 160.0
	fight_tex.margin_top = -105.0
	fight_tex.margin_bottom = 5.0
	root.add_child(fight_tex)

	# Countdown — Lobster font, golden yellow with thick black outline
	var countdown := Label.new()
	countdown.add_font_override("font", _make_lobster_font(64))
	countdown.add_color_override("font_color", Color(1, 0.88, 0.1, 1))
	countdown.anchor_left = 0.0
	countdown.anchor_right = 1.0
	countdown.anchor_top = 0.5
	countdown.anchor_bottom = 0.5
	countdown.margin_top = 20.0
	countdown.margin_bottom = 100.0
	countdown.align = Label.ALIGN_CENTER
	root.add_child(countdown)

	for i in range(3, 0, -1):
		countdown.text = str(i)
		yield(get_tree().create_timer(1.0), "timeout")

	GameState.fight_background_index = randi() % GameState.FIGHT_BACKGROUND_COUNT
	_music.stop()
	get_tree().change_scene("res://scenes/Fight.tscn")

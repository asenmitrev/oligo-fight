extends Control

var p1_index := 0
var p2_index := 1
var p1_confirmed := false
var p2_confirmed := false

const UI_TEXT_SCALE := 1.55
const PREVIEW_SCALE := 1.80
const SLOT_WIDTH := 256
const PREVIEW_OFFSET := Vector2(0, -25)
const FEET_FROM_BOTTOM := 75  # px from bottom of screen where character feet sit
const NAME_LABEL_STAGGER := 30  # vertical offset between adjacent fighter name rows
const BORDER_WIDTH_NORMAL := 5
const BORDER_WIDTH_CONFIRMED := 12
const P2_BORDER_INSET := 7  # P2 border is drawn inset inside P1's border

onready var P1_COLOR := GameState.P1_COLOR
onready var P2_COLOR := GameState.P2_COLOR

var char_slots: Array = []
var char_previews: Array = []
var p1_borders: Array = []
var p2_borders: Array = []

var LOBSTER_FONT: BitmapFont = load("res://assets/fonts/lobster52.fnt")
var LOBSTER_FONT_28: BitmapFont = load("res://assets/fonts/lobster28.fnt")

onready var select_grid: Control = $SelectGrid
onready var p1_tween: Tween = Tween.new()
onready var p2_tween: Tween = Tween.new()
onready var _music: AudioStreamPlayer = $Music

func _ready() -> void:
	add_child(p1_tween)
	add_child(p2_tween)
	_setup_select_grid()
	call_deferred("_apply_ui_text_scale")
	_update_ui()

	var stream: AudioStream = preload("res://assets/music/character-select.ogg")
	stream.loop = true
	_music.stream = stream
	_music.play()

func _make_lobster_font(size: int) -> BitmapFont:
	# We have two atlases (28px and 52px); pick the closer one.
	# Godot will not resample the bitmap, so the actual rendered size matches the atlas.
	return LOBSTER_FONT_28 if size <= 40 else LOBSTER_FONT


func _setup_select_grid() -> void:
	var vp := get_viewport().size
	var sprite_y := vp.y - FEET_FROM_BOTTOM
# one center-x per character — add an entry here if you add a character
	var centers_x := [vp.x * 0.071, vp.x * 0.143, vp.x * 0.214, vp.x * 0.286, vp.x * 0.357, vp.x * 0.429, vp.x * 0.500, vp.x * 0.571, vp.x * 0.643, vp.x * 0.714, vp.x * 0.786, vp.x * 0.857, vp.x * 0.929]
	assert(CharacterDB.all_characters.size() == centers_x.size(), "centers_x needs one entry per character")

	for i in range(CharacterDB.all_characters.size()):
		var char_def = CharacterDB.all_characters[i]

		var slot := Control.new()
		slot.rect_position = Vector2(centers_x[i] - SLOT_WIDTH / 2.0, sprite_y - SLOT_WIDTH)
		slot.rect_size = Vector2(SLOT_WIDTH, SLOT_WIDTH + 34)
		select_grid.add_child(slot)
		char_slots.append(slot)

		var ps: float = PREVIEW_SCALE * (char_def.sprite_scale as float)
		var tex: Texture = char_def.get_preview_sprite_frames().get_frame("idle", 0)
		var sprite_rendered_size := tex.get_size() * ps
		var border_size := Vector2(sprite_rendered_size.x * 0.7, sprite_rendered_size.y)
		var sprite_center := Vector2(SLOT_WIDTH / 2.0, SLOT_WIDTH) + PREVIEW_OFFSET
		var border_pos := sprite_center - border_size / 2.0

		var p1_b := _make_border_panel(P1_COLOR, border_pos, border_size)
		slot.add_child(p1_b)
		p1_borders.append(p1_b)

		var ins := P2_BORDER_INSET
		var p2_b := _make_border_panel(P2_COLOR, border_pos + Vector2(ins, ins), border_size - Vector2(ins * 2, ins * 2))
		slot.add_child(p2_b)
		p2_borders.append(p2_b)

		var preview := TextureRect.new()
		preview.rect_position = Vector2(SLOT_WIDTH / 2.0, SLOT_WIDTH) + PREVIEW_OFFSET - sprite_rendered_size / 2.0
		preview.rect_size = sprite_rendered_size
		preview.flip_h = (i >= centers_x.size() / 2)
		preview.texture = tex
		preview.expand = true
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(preview)
		char_previews.append(preview)

		var name_lbl := Label.new()
		# Stagger odd-indexed names downward so adjacent names (slots overlap horizontally)
		# don't visually collide.
		var name_y := SLOT_WIDTH + 4 + (NAME_LABEL_STAGGER if i % 2 == 1 else 0)
		name_lbl.rect_position = Vector2(0, name_y)
		name_lbl.rect_size = Vector2(SLOT_WIDTH, 30)
		name_lbl.align = Label.ALIGN_CENTER
		name_lbl.text = char_def.display_name
		name_lbl.add_font_override("font", LOBSTER_FONT_28)
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




func _input(event: InputEvent) -> void:
	if event.is_action_pressed("start") or event.is_action_pressed("p1_kick") or event.is_action_pressed("p2_kick"):
		_music.stop()
		get_tree().change_scene("res://scenes/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:

	var num := CharacterDB.all_characters.size()

	# --- P1 navigation & confirm ---
	if not p1_confirmed:
		if event.is_action_pressed("p1_left"):
			p1_index = (p1_index + OsUtil.reverse_direction(-1) + num) % num
			_update_ui()
			_flash_selection(p1_borders[p1_index], P1_COLOR, p1_tween)
		elif event.is_action_pressed("p1_right"):
			p1_index = (p1_index + OsUtil.reverse_direction(1) + num) % num
			_update_ui()
			_flash_selection(p1_borders[p1_index], P1_COLOR, p1_tween)
		elif event.is_action_pressed("p1_confirm"):
			p1_confirmed = true
			_update_ui()
			_set_border_width(p1_borders[p1_index].get_stylebox("panel"), BORDER_WIDTH_CONFIRMED)
			_flash_selection(p1_borders[p1_index], P1_COLOR, p1_tween, true)
			_check_start()
	elif event.is_action_pressed("p1_confirm") and not p2_confirmed:
		# P1 is confirmed — pressing confirm again toggles back (only if P2 hasn't confirmed)
		p1_confirmed = false
		_update_ui()
		_set_border_width(p1_borders[p1_index].get_stylebox("panel"), BORDER_WIDTH_NORMAL)

	# --- P2 navigation & confirm ---
	if not p2_confirmed:
		if event.is_action_pressed("p2_left"):
			p2_index = (p2_index + OsUtil.reverse_direction(-1) + num) % num
			_update_ui()
			_flash_selection(p2_borders[p2_index], P2_COLOR, p2_tween)
		elif event.is_action_pressed("p2_right"):
			p2_index = (p2_index + OsUtil.reverse_direction(1) + num) % num
			_update_ui()
			_flash_selection(p2_borders[p2_index], P2_COLOR, p2_tween)
		elif event.is_action_pressed("p2_confirm"):
			p2_confirmed = true
			_update_ui()
			_set_border_width(p2_borders[p2_index].get_stylebox("panel"), BORDER_WIDTH_CONFIRMED)
			_flash_selection(p2_borders[p2_index], P2_COLOR, p2_tween, true)
			_check_start()
	elif event.is_action_pressed("p2_confirm") and not p1_confirmed:
		# P2 is confirmed — pressing confirm again toggles back (only if P1 hasn't confirmed)
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

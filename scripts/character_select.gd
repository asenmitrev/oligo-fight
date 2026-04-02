extends Control

var p1_index := 0
var p2_index := 1
var p1_confirmed := false
var p2_confirmed := false

const UI_TEXT_SCALE := 1.55
# 512× frames @ PREVIEW_SCALE; offset (0,-256) — sprite draws ~230px above/below center; need top margin so heads aren’t clipped
const PREVIEW_SCALE := 0.90
const SLOT_WIDTH := 256
const PREVIEW_OFFSET := Vector2(0, -128)
const SLOT_MARGIN_TOP := 145
const FEET_BELOW_GRID_TOP := 102.0
const SLOT_TOTAL_HEIGHT := 315
const SELECT_GRID_HEIGHT := SLOT_TOTAL_HEIGHT - SLOT_MARGIN_TOP
# Design res 768p — nudge feet slightly below old 641 to line up with priest on bg
const DESIGN_VIEWPORT_HEIGHT := 384.0
const PREVIEW_SPRITE_Y_DESIGN := 334.0

const P1_COLOR := Color(1.0, 0.2, 0.2, 1.0)
const P2_COLOR := Color(0.2, 0.5, 1.0, 1.0)
const BORDER_WIDTH_NORMAL := 5
const BORDER_WIDTH_CONFIRMED := 12

var char_slots: Array = []
var char_previews: Array = []
var p1_borders: Array = []
var p2_borders: Array = []

var _pause_menu: CanvasLayer
var _resume_btn: Button
var _quit_btn: Button
var _is_paused: bool = false

onready var fight_label: Label = $FightLabel
onready var select_grid: Control = $SelectGrid
onready var p1_tween: Tween = Tween.new()
onready var p2_tween: Tween = Tween.new()


func _ready() -> void:
	add_child(p1_tween)
	add_child(p2_tween)
	_setup_select_grid()
	_build_pause_menu()
	call_deferred("_apply_ui_text_scale")
	_update_ui()


func _setup_select_grid() -> void:
	var vp := get_viewport().size
	var num_chars := CharacterDB.all_characters.size()

	select_grid.rect_position = Vector2(
		0,
		vp.y * (PREVIEW_SPRITE_Y_DESIGN / DESIGN_VIEWPORT_HEIGHT) - FEET_BELOW_GRID_TOP
	)
	select_grid.rect_size = Vector2(vp.x, SELECT_GRID_HEIGHT)

	# Two side positions matching where the old big sprites were
	var slot_x := [
		vp.x * 0.25 - SLOT_WIDTH / 2.0,
		vp.x * 0.75 - SLOT_WIDTH / 2.0,
	]
	var preview_y := SLOT_MARGIN_TOP + int(FEET_BELOW_GRID_TOP) + 50
	var selection_box_size := 256

	for i in range(num_chars):
		var char_def = CharacterDB.all_characters[i]

		# Slot sits partly above select_grid so tall sprites + borders share one rect (no floating box)
		var slot := Control.new()
		slot.rect_position = Vector2(slot_x[i], -SLOT_MARGIN_TOP)
		slot.rect_size = Vector2(SLOT_WIDTH, SLOT_TOTAL_HEIGHT)
		select_grid.add_child(slot)
		char_slots.append(slot)

		# P1 selection box (red) — behind sprite
		var p1_b := Panel.new()
		p1_b.rect_position = Vector2(0, preview_y - selection_box_size)
		p1_b.rect_size = Vector2(SLOT_WIDTH, selection_box_size)
		p1_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p1_sty := StyleBoxFlat.new()
		p1_sty.bg_color = Color(0, 0, 0, 0)
		p1_sty.border_color = P1_COLOR
		p1_sty.border_width_left = BORDER_WIDTH_NORMAL
		p1_sty.border_width_right = BORDER_WIDTH_NORMAL
		p1_sty.border_width_top = BORDER_WIDTH_NORMAL
		p1_sty.border_width_bottom = BORDER_WIDTH_NORMAL
		p1_b.add_stylebox_override("panel", p1_sty)
		p1_b.visible = false
		slot.add_child(p1_b)
		p1_borders.append(p1_b)

		# P2 selection box (blue, inset)
		var p2_b := Panel.new()
		p2_b.rect_position = Vector2(7, preview_y - selection_box_size + 7)
		p2_b.rect_size = Vector2(SLOT_WIDTH - 14, selection_box_size - 14)
		p2_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p2_sty := StyleBoxFlat.new()
		p2_sty.bg_color = Color(0, 0, 0, 0)
		p2_sty.border_color = P2_COLOR
		p2_sty.border_width_left = BORDER_WIDTH_NORMAL
		p2_sty.border_width_right = BORDER_WIDTH_NORMAL
		p2_sty.border_width_top = BORDER_WIDTH_NORMAL
		p2_sty.border_width_bottom = BORDER_WIDTH_NORMAL
		p2_b.add_stylebox_override("panel", p2_sty)
		p2_b.visible = false
		slot.add_child(p2_b)
		p2_borders.append(p2_b)

		var preview := AnimatedSprite.new()
		preview.position = Vector2(SLOT_WIDTH / 2.0, preview_y)
		preview.offset = PREVIEW_OFFSET
		preview.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
		preview.flip_h = (i == 1)
		preview.frames = char_def.get_preview_sprite_frames()
		preview.play("idle")
		slot.add_child(preview)
		char_previews.append(preview)

		# Character name label at bottom of slot
		var name_lbl := Label.new()
		name_lbl.rect_position = Vector2(0, SLOT_TOTAL_HEIGHT - 34)
		name_lbl.rect_size = Vector2(SLOT_WIDTH, 28)
		name_lbl.align = Label.ALIGN_CENTER
		name_lbl.text = char_def.display_name
		slot.add_child(name_lbl)


func _apply_ui_text_scale() -> void:
	var labels: Array = [
		$Title,
		$VSLabel,
		$FightLabel,
	]
	for n in labels:
		var lbl: Label = n as Label
		lbl.rect_pivot_offset = lbl.rect_size / 2.0
		lbl.rect_scale = Vector2(UI_TEXT_SCALE, UI_TEXT_SCALE)


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
	_resume_btn.connect("pressed", self, "_on_pause_resume")
	vbox.add_child(_resume_btn)

	_quit_btn = Button.new()
	_quit_btn.text = "Quit Game"
	_quit_btn.connect("pressed", self, "_on_pause_quit")
	vbox.add_child(_quit_btn)

	var r_to_q: NodePath = _resume_btn.get_path_to(_quit_btn)
	var q_to_r: NodePath = _quit_btn.get_path_to(_resume_btn)
	_resume_btn.focus_neighbour_top = r_to_q
	_resume_btn.focus_neighbour_bottom = r_to_q
	_quit_btn.focus_neighbour_top = q_to_r
	_quit_btn.focus_neighbour_bottom = q_to_r

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


func _resume_game() -> void:
	_is_paused = false
	_pause_menu.visible = false
	if _resume_btn.has_focus():
		_resume_btn.release_focus()
	elif _quit_btn.has_focus():
		_quit_btn.release_focus()


func _on_pause_resume() -> void:
	_resume_game()


func _on_pause_quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _is_paused:
		if event.is_action_pressed("ui_cancel"):
			if not event.is_action_pressed("pause"):
				_resume_game()
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("p1_left"):
		if not p1_confirmed:
			p1_index = (p1_index - 1 + CharacterDB.all_characters.size()) % CharacterDB.all_characters.size()
			_update_ui()
			_flash_selection(p1_borders[p1_index], P1_COLOR, p1_tween)
	elif event.is_action_pressed("p1_right"):
		if not p1_confirmed:
			p1_index = (p1_index + 1) % CharacterDB.all_characters.size()
			_update_ui()
			_flash_selection(p1_borders[p1_index], P1_COLOR, p1_tween)
	elif event.is_action_pressed("p1_confirm"):
		if not p1_confirmed:
			p1_confirmed = true
			_update_ui()
			_flash_selection(p1_borders[p1_index], P1_COLOR, p1_tween, true)
			_check_start()
	elif event.is_action_pressed("p2_left"):
		if not p2_confirmed:
			p2_index = (p2_index - 1 + CharacterDB.all_characters.size()) % CharacterDB.all_characters.size()
			_update_ui()
			_flash_selection(p2_borders[p2_index], P2_COLOR, p2_tween)
	elif event.is_action_pressed("p2_right"):
		if not p2_confirmed:
			p2_index = (p2_index + 1) % CharacterDB.all_characters.size()
			_update_ui()
			_flash_selection(p2_borders[p2_index], P2_COLOR, p2_tween)
	elif event.is_action_pressed("p2_confirm"):
		if not p2_confirmed:
			p2_confirmed = true
			_update_ui()
			_flash_selection(p2_borders[p2_index], P2_COLOR, p2_tween, true)
			_check_start()


func _update_ui() -> void:
	for i in range(char_slots.size()):
		var p1_b : Panel = p1_borders[i]
		var p2_b : Panel = p2_borders[i]
		
		p1_b.visible = (p1_index == i)
		p2_b.visible = (p2_index == i)
		
		var p1_sty : StyleBoxFlat = p1_b.get_stylebox("panel")
		var p2_sty : StyleBoxFlat = p2_b.get_stylebox("panel")
		
		var p1_w := BORDER_WIDTH_CONFIRMED if p1_confirmed else BORDER_WIDTH_NORMAL
		p1_sty.border_width_left = p1_w
		p1_sty.border_width_right = p1_w
		p1_sty.border_width_top = p1_w
		p1_sty.border_width_bottom = p1_w
		
		var p2_w := BORDER_WIDTH_CONFIRMED if p2_confirmed else BORDER_WIDTH_NORMAL
		p2_sty.border_width_left = p2_w
		p2_sty.border_width_right = p2_w
		p2_sty.border_width_top = p2_w
		p2_sty.border_width_bottom = p2_w


func _flash_selection(panel: Panel, color: Color, tween: Tween, is_confirm: bool = false) -> void:
	var style : StyleBoxFlat = panel.get_stylebox("panel")
	tween.stop_all()
	
	var flash_color = color
	flash_color.a = 0.7 if is_confirm else 0.3
	var duration = 0.5 if is_confirm else 0.2
	
	# Flash background
	tween.interpolate_property(style, "bg_color", flash_color, Color(0, 0, 0, 0), duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	# Flash border to white then back to player color
	tween.interpolate_property(style, "border_color", Color.white, color, duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	
	tween.start()

func _check_start() -> void:
	if p1_confirmed and p2_confirmed:
		var p1_def = CharacterDB.all_characters[p1_index]
		var p2_def = CharacterDB.all_characters[p2_index]
		GameState.p1_character = p1_def.display_name
		GameState.p2_character = p2_def.display_name
		GameState.p2_is_mirror = (p1_index == p2_index)
		fight_label.visible = true
		for i in range(3, 0, -1):
			fight_label.text = str(i)
			yield(get_tree().create_timer(1.0), "timeout")
		fight_label.text = "FIGHT!"
		yield(get_tree().create_timer(0.5), "timeout")
		GameState.fight_background_index = randi() % GameState.FIGHT_BACKGROUND_COUNT
		get_tree().change_scene("res://scenes/Fight.tscn")

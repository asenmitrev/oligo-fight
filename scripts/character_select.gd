extends Control

var p1_index := 0
var p2_index := 1
var p1_confirmed := false
var p2_confirmed := false

const UI_TEXT_SCALE := 1.55
const SLOT_WIDTH := 280
# 512× frames @ PREVIEW_SCALE; offset (0,-256) — sprite draws ~230px above/below center; need top margin so heads aren’t clipped
const PREVIEW_SCALE := 0.9
const PREVIEW_OFFSET := Vector2(0, -256)
const SLOT_MARGIN_TOP := 290
# Feet anchor: preview_y_in_slot places the sprite; +PREVIEW_Y_NUDGE lowers characters on the bg
const FEET_BELOW_GRID_TOP := 204.0
const SLOT_TOTAL_HEIGHT := 630
# Selection frame ends at feet + pad, capped above the name label (not full slot height)
const PREVIEW_Y_NUDGE := 100
const SELECTION_BOX_PAD_BELOW_FEET := 12
# Pixels removed from the computed box height (tighter frame around the sprite)
const SELECTION_BOX_HEIGHT_TRIM := 64
const SELECT_GRID_HEIGHT := SLOT_TOTAL_HEIGHT - SLOT_MARGIN_TOP
# Design res 768p — nudge feet slightly below old 641 to line up with priest on bg
const DESIGN_VIEWPORT_HEIGHT := 768.0
const PREVIEW_SPRITE_Y_DESIGN := 668.0

var char_slots: Array = []
var char_previews: Array = []
var p1_borders: Array = []
var p2_borders: Array = []

onready var fight_label: Label = $FightLabel
onready var select_grid: Control = $SelectGrid


func _ready() -> void:
	_setup_select_grid()
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
	var preview_y_in_slot := SLOT_MARGIN_TOP + int(FEET_BELOW_GRID_TOP)
	var preview_y := preview_y_in_slot + PREVIEW_Y_NUDGE
	var selection_box_height := int(
		min(preview_y + SELECTION_BOX_PAD_BELOW_FEET, SLOT_TOTAL_HEIGHT - 34)
	) - SELECTION_BOX_HEIGHT_TRIM
	selection_box_height = max(selection_box_height, 380)

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
		p1_b.rect_position = Vector2(0, 0)
		p1_b.rect_size = Vector2(SLOT_WIDTH, selection_box_height)
		p1_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p1_sty := StyleBoxFlat.new()
		p1_sty.bg_color = Color(0, 0, 0, 0)
		p1_sty.border_color = Color(1.0, 0.2, 0.2, 1.0)
		p1_sty.border_width_left = 5
		p1_sty.border_width_right = 5
		p1_sty.border_width_top = 5
		p1_sty.border_width_bottom = 5
		p1_b.add_stylebox_override("panel", p1_sty)
		p1_b.visible = false
		slot.add_child(p1_b)
		p1_borders.append(p1_b)

		# P2 selection box (blue, inset)
		var p2_b := Panel.new()
		p2_b.rect_position = Vector2(7, 7)
		p2_b.rect_size = Vector2(SLOT_WIDTH - 14, selection_box_height - 14)
		p2_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p2_sty := StyleBoxFlat.new()
		p2_sty.bg_color = Color(0, 0, 0, 0)
		p2_sty.border_color = Color(0.2, 0.5, 1.0, 1.0)
		p2_sty.border_width_left = 5
		p2_sty.border_width_right = 5
		p2_sty.border_width_top = 5
		p2_sty.border_width_bottom = 5
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p1_left"):
		if not p1_confirmed:
			p1_index = (p1_index - 1 + CharacterDB.all_characters.size()) % CharacterDB.all_characters.size()
			_update_ui()
	elif event.is_action_pressed("p1_right"):
		if not p1_confirmed:
			p1_index = (p1_index + 1) % CharacterDB.all_characters.size()
			_update_ui()
	elif event.is_action_pressed("p1_confirm"):
		if not p1_confirmed:
			p1_confirmed = true
			_update_ui()
			_check_start()
	elif event.is_action_pressed("p2_left"):
		if not p2_confirmed:
			p2_index = (p2_index - 1 + CharacterDB.all_characters.size()) % CharacterDB.all_characters.size()
			_update_ui()
	elif event.is_action_pressed("p2_right"):
		if not p2_confirmed:
			p2_index = (p2_index + 1) % CharacterDB.all_characters.size()
			_update_ui()
	elif event.is_action_pressed("p2_confirm"):
		if not p2_confirmed:
			p2_confirmed = true
			_update_ui()
			_check_start()


func _update_ui() -> void:
	for i in range(char_slots.size()):
		p1_borders[i].visible = (p1_index == i)
		p2_borders[i].visible = (p2_index == i)

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

extends Control

var p1_index := 0
var p2_index := 1
var p1_confirmed := false
var p2_confirmed := false

const UI_TEXT_SCALE := 1.55
const SLOT_WIDTH := 280
const SLOT_HEIGHT := 340

var char_slots: Array = []
var char_previews: Array = []
var p1_borders: Array = []
var p2_borders: Array = []

onready var p1_char_name: Label = $P1CharName
onready var p2_char_name: Label = $P2CharName
onready var fight_label: Label = $FightLabel
onready var select_grid: Control = $SelectGrid


func _ready() -> void:
	_setup_select_grid()
	call_deferred("_apply_ui_text_scale")
	_update_ui()


func _setup_select_grid() -> void:
	var vp := get_viewport().size
	var num_chars := CharacterDB.all_characters.size()

	select_grid.rect_position = Vector2(0, vp.y * 0.20)
	select_grid.rect_size = Vector2(vp.x, SLOT_HEIGHT)

	# Two side positions matching where the old big sprites were
	var slot_x := [
		vp.x * 0.25 - SLOT_WIDTH / 2.0,
		vp.x * 0.75 - SLOT_WIDTH / 2.0,
	]

	for i in range(num_chars):
		var char_def = CharacterDB.all_characters[i]

		# No background — use a plain Control as the slot container
		var slot := Control.new()
		slot.rect_position = Vector2(slot_x[i], 0)
		slot.rect_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
		select_grid.add_child(slot)
		char_slots.append(slot)

		# Character preview sprite
		var preview := AnimatedSprite.new()
		preview.position = Vector2(SLOT_WIDTH / 2.0, SLOT_HEIGHT * 0.60)
		preview.offset = Vector2(0, -256)
		preview.scale = Vector2(0.42, 0.42)
		preview.flip_h = (i == 1)
		preview.frames = char_def.get_preview_sprite_frames()
		preview.play("idle")
		slot.add_child(preview)
		char_previews.append(preview)

		# Character name label at bottom of slot
		var name_lbl := Label.new()
		name_lbl.rect_position = Vector2(0, SLOT_HEIGHT - 34)
		name_lbl.rect_size = Vector2(SLOT_WIDTH, 28)
		name_lbl.align = Label.ALIGN_CENTER
		name_lbl.text = char_def.display_name
		slot.add_child(name_lbl)

		# P1 selection border (red, outer edge)
		var p1_b := Panel.new()
		p1_b.rect_position = Vector2(0, 0)
		p1_b.rect_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
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

		# P2 selection border (blue, inset from P1 border)
		var p2_b := Panel.new()
		p2_b.rect_position = Vector2(7, 7)
		p2_b.rect_size = Vector2(SLOT_WIDTH - 14, SLOT_HEIGHT - 14)
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


func _apply_ui_text_scale() -> void:
	var labels: Array = [
		$Title,
		$P1Header,
		$P2Header,
		$P1CharName,
		$P2CharName,
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
	var p1_def = CharacterDB.all_characters[p1_index]
	var p2_def = CharacterDB.all_characters[p2_index]
	var same := p1_index == p2_index

	# Update selection borders
	for i in range(char_slots.size()):
		p1_borders[i].visible = (p1_index == i)
		p2_borders[i].visible = (p2_index == i)

	# Update name labels under the slots
	p1_char_name.text = p1_def.display_name
	p1_char_name.modulate = Color(1, 1, 1)
	p2_char_name.text = p2_def.display_name
	p2_char_name.modulate = Color(1, 1, 1)


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

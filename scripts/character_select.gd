extends Control

var p1_index := 0
var p2_index := 1
var p1_confirmed := false
var p2_confirmed := false

const UI_TEXT_SCALE := 1.55

onready var p1_char_name: Label = $P1CharName
onready var p2_char_name: Label = $P2CharName
onready var p1_status: Label = $P1Status
onready var p2_status: Label = $P2Status
onready var fight_label: Label = $FightLabel
onready var p1_sprite: AnimatedSprite = $P1Sprite
onready var p2_sprite: AnimatedSprite = $P2Sprite


func _ready() -> void:
	var vp := get_viewport().size
	p1_sprite.position = Vector2(vp.x * 0.25, vp.y * 0.50)
	p2_sprite.position = Vector2(vp.x * 0.75, vp.y * 0.50)
	call_deferred("_apply_ui_text_scale")
	_update_ui()


func _apply_ui_text_scale() -> void:
	var labels: Array = [
		$Title,
		$P1Header,
		$P2Header,
		$P1CharName,
		$P2CharName,
		$P1Keys,
		$P2Keys,
		$P1Status,
		$P2Status,
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
		if not p1_confirmed and p1_index != p2_index:
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
		if not p2_confirmed and p1_index != p2_index:
			p2_confirmed = true
			_update_ui()
			_check_start()


func _update_ui() -> void:
	var same := p1_index == p2_index

	var p1_def = CharacterDB.all_characters[p1_index]
	var p2_def = CharacterDB.all_characters[p2_index]

	p1_char_name.text = "<  " + p1_def.display_name + "  >"
	p1_char_name.modulate = p1_def.modulate
	p1_sprite.modulate = p1_def.modulate
	p1_sprite.frames = p1_def.get_preview_sprite_frames()
	p1_sprite.play("idle")

	p2_char_name.text = "<  " + p2_def.display_name + "  >"
	p2_char_name.modulate = p2_def.modulate
	p2_sprite.modulate = p2_def.modulate
	p2_sprite.frames = p2_def.get_preview_sprite_frames()
	p2_sprite.play("idle")

	if p1_confirmed:
		p1_status.text = "READY!"
		p1_status.add_color_override("font_color", Color(0.2, 1, 0.2))
	elif same:
		p1_status.text = "Already taken - pick another!"
		p1_status.add_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		p1_status.text = "Z or [A] to confirm"
		p1_status.add_color_override("font_color", Color(1, 1, 1))

	if p2_confirmed:
		p2_status.text = "READY!"
		p2_status.add_color_override("font_color", Color(0.2, 1, 0.2))
	elif same:
		p2_status.text = "Already taken - pick another!"
		p2_status.add_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		p2_status.text = "F or [A] to confirm"
		p2_status.add_color_override("font_color", Color(1, 1, 1))


func _check_start() -> void:
	if p1_confirmed and p2_confirmed:
		var p1_def = CharacterDB.all_characters[p1_index]
		var p2_def = CharacterDB.all_characters[p2_index]
		GameState.p1_character = p1_def.display_name
		GameState.p2_character = p2_def.display_name
		fight_label.visible = true
		for i in range(3, 0, -1):
			fight_label.text = str(i)
			yield(get_tree().create_timer(1.0), "timeout")
		fight_label.text = "FIGHT!"
		yield(get_tree().create_timer(0.5), "timeout")
		GameState.fight_background_index = randi() % GameState.FIGHT_BACKGROUND_COUNT
		get_tree().change_scene("res://scenes/Platformer.tscn")

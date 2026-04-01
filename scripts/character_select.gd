extends Control

const CHARACTERS := [
	{"name": "Simonka", "color": Color(1, 1, 1, 1)},
	{"name": "Evil Simonka", "color": Color(1, 0.75, 0.85, 1)},
	{"name": "Georgi", "color": Color(1, 1, 1, 1)},
]

export var georgi_idle_frames: SpriteFrames

var p1_index := 0
var p2_index := 1
var p1_confirmed := false
var p2_confirmed := false
var _simonka_idle_frames: SpriteFrames

onready var p1_char_name: Label = $P1CharName
onready var p2_char_name: Label = $P2CharName
onready var p1_status: Label = $P1Status
onready var p2_status: Label = $P2Status
onready var fight_label: Label = $FightLabel
onready var p1_sprite: AnimatedSprite = $P1Sprite
onready var p2_sprite: AnimatedSprite = $P2Sprite

func _ready() -> void:
	_simonka_idle_frames = _build_simonka_idle_frames()
	var vp := get_viewport().size
	p1_sprite.position = Vector2(vp.x * 0.25, vp.y * 0.50)
	p2_sprite.position = Vector2(vp.x * 0.75, vp.y * 0.50)
	_update_ui()

func _build_simonka_idle_frames() -> SpriteFrames:
	var tex: Texture = load("res://assets/simonka-idle.png")
	var sf := SpriteFrames.new()
	sf.clear_all()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 8.0)
	for coords in [Vector2(0, 0), Vector2(512, 0), Vector2(0, 512), Vector2(512, 512)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(coords, Vector2(512, 512))
		sf.add_frame("idle", atlas)
	return sf

func _unhandled_input(event: InputEvent) -> void:
	# P1 controls
	if event.is_action_pressed("p1_left"):
		if not p1_confirmed:
			p1_index = (p1_index - 1 + CHARACTERS.size()) % CHARACTERS.size()
			_update_ui()
	elif event.is_action_pressed("p1_right"):
		if not p1_confirmed:
			p1_index = (p1_index + 1) % CHARACTERS.size()
			_update_ui()
	elif event.is_action_pressed("p1_confirm"):
		if not p1_confirmed and p1_index != p2_index:
			p1_confirmed = true
			_update_ui()
			_check_start()
	# P2 controls
	elif event.is_action_pressed("p2_left"):
		if not p2_confirmed:
			p2_index = (p2_index - 1 + CHARACTERS.size()) % CHARACTERS.size()
			_update_ui()
	elif event.is_action_pressed("p2_right"):
		if not p2_confirmed:
			p2_index = (p2_index + 1) % CHARACTERS.size()
			_update_ui()
	elif event.is_action_pressed("p2_confirm"):
		if not p2_confirmed and p1_index != p2_index:
			p2_confirmed = true
			_update_ui()
			_check_start()

func _get_idle_frames(char_name: String) -> SpriteFrames:
	if char_name == "Georgi":
		return georgi_idle_frames
	return _simonka_idle_frames

func _update_ui() -> void:
	var same := p1_index == p2_index

	var p1_char: Dictionary = CHARACTERS[p1_index]
	var p2_char: Dictionary = CHARACTERS[p2_index]

	p1_char_name.text = "<  " + p1_char.name + "  >"
	p1_char_name.modulate = p1_char.color
	p1_sprite.modulate = p1_char.color
	p1_sprite.frames = _get_idle_frames(p1_char.name)
	p1_sprite.play("idle")

	p2_char_name.text = "<  " + p2_char.name + "  >"
	p2_char_name.modulate = p2_char.color
	p2_sprite.modulate = p2_char.color
	p2_sprite.frames = _get_idle_frames(p2_char.name)
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
		GameState.p1_character = CHARACTERS[p1_index].name
		GameState.p2_character = CHARACTERS[p2_index].name
		fight_label.visible = true
		for i in range(3, 0, -1):
			fight_label.text = str(i)
			yield(get_tree().create_timer(1.0), "timeout")
		fight_label.text = "FIGHT!"
		yield(get_tree().create_timer(0.5), "timeout")
		get_tree().change_scene("res://scenes/Platformer.tscn")

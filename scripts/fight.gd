extends Node2D

const FIGHT_BACKGROUNDS := [
	preload("res://assets/bg.png"),
	preload("res://assets/bg2.png"),
	preload("res://assets/bg3.png"),
	preload("res://assets/bg4.png"),
]

onready var win_screen: ColorRect = $HUD/WinScreen
onready var win_label: Label = $HUD/WinScreen/WinLabel
onready var p1_wins_label: Label = $HUD/P1WinsLabel
onready var p2_wins_label: Label = $HUD/P2WinsLabel
onready var camera: Camera2D = $Camera2D

var p1_wins: int = 0
var p2_wins: int = 0
var current_round: int = 1
var round_in_progress: bool = false

var _pause_menu: CanvasLayer
var _pause_char_btn: Button
var _pause_quit_btn: Button
var _is_paused: bool = false
var _was_round_in_progress: bool = false

# Camera Shake
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _camera_origin: Vector2

func _ready() -> void:
	assert(FIGHT_BACKGROUNDS.size() == GameState.FIGHT_BACKGROUND_COUNT)
	_apply_fight_background()
	_build_pause_menu()
	_apply_character_selections()
	_camera_origin = camera.position
	
	for player in get_tree().get_nodes_in_group("players"):
		player.connect("defeated", self, "_on_player_defeated")
		player.connect("hit_landed", self, "_on_player_hit_landed")
		
	_update_wins_display()
	_start_round()

func _process(delta: float) -> void:
	if _shake_duration > 0:
		_shake_duration -= delta
		var offset = Vector2(
			rand_range(-_shake_intensity, _shake_intensity),
			rand_range(-_shake_intensity, _shake_intensity)
		)
		camera.position = _camera_origin + offset
		if _shake_duration <= 0:
			camera.position = _camera_origin

func shake_camera(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration

func _on_player_hit_landed(is_heavy: bool) -> void:
	if is_heavy:
		shake_camera(8.0, 0.15)
	else:
		shake_camera(3.0, 0.1)

func _apply_fight_background() -> void:
	var idx: int = int(clamp(
			GameState.fight_background_index,
			0,
			FIGHT_BACKGROUNDS.size() - 1))
	$Background.texture = FIGHT_BACKGROUNDS[idx]

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

	_pause_char_btn = Button.new()
	_pause_char_btn.text = "Character Select"
	_pause_char_btn.connect("pressed", self, "_on_pause_character_select")
	vbox.add_child(_pause_char_btn)

	_pause_quit_btn = Button.new()
	_pause_quit_btn.text = "Quit Game"
	_pause_quit_btn.connect("pressed", self, "_on_pause_quit")
	vbox.add_child(_pause_quit_btn)

	var p1_to_p2: NodePath = _pause_char_btn.get_path_to(_pause_quit_btn)
	var p2_to_p1: NodePath = _pause_quit_btn.get_path_to(_pause_char_btn)
	_pause_char_btn.focus_neighbour_top = p1_to_p2
	_pause_char_btn.focus_neighbour_bottom = p1_to_p2
	_pause_quit_btn.focus_neighbour_top = p2_to_p1
	_pause_quit_btn.focus_neighbour_bottom = p2_to_p1

	_pause_menu.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _is_paused:
			_resume_game()
		else:
			_pause_game()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_paused:
		return
	if event.is_action_pressed("ui_cancel"):
		if event.is_action_pressed("pause"):
			return
		_resume_game()
		get_viewport().set_input_as_handled()

func _pause_game() -> void:
	_is_paused = true
	_was_round_in_progress = round_in_progress
	_set_players_frozen(true)
	_pause_menu.visible = true
	_pause_char_btn.call_deferred("grab_focus")

func _resume_game() -> void:
	_is_paused = false
	_pause_menu.visible = false
	if _pause_char_btn.has_focus():
		_pause_char_btn.release_focus()
	elif _pause_quit_btn.has_focus():
		_pause_quit_btn.release_focus()
	if _was_round_in_progress:
		_set_players_frozen(false)

func _on_pause_character_select() -> void:
	_is_paused = false
	get_tree().change_scene("res://scenes/CharacterSelect.tscn")

func _on_pause_quit() -> void:
	get_tree().quit()

func _apply_character_selections() -> void:
	_configure_player($Player, GameState.p1_character, false)
	_configure_player($Player2, GameState.p2_character, GameState.p2_is_mirror)

func _configure_player(player: KinematicBody2D, char_name: String, is_mirror: bool) -> void:
	var def = CharacterDB.get_by_display_name(char_name)
	if def == null:
		def = CharacterDB.all_characters[0]
	player.apply_character(def)
	if is_mirror:
		player.anim.modulate = Color(1, 0.75, 0.85, 1)

func _update_wins_display() -> void:
	p1_wins_label.text = _wins_dots(p1_wins)
	p2_wins_label.text = _wins_dots(p2_wins)

func _wins_dots(wins: int) -> String:
	var filled := "●".repeat(wins)
	var empty := "○".repeat(2 - wins)
	return filled + empty

func _set_players_frozen(frozen: bool) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		player.frozen = frozen

func _start_round() -> void:
	round_in_progress = true
	_set_players_frozen(false)

func _on_player_defeated() -> void:
	if not round_in_progress:
		return
	round_in_progress = false
	_set_players_frozen(true)
	shake_camera(15.0, 0.5) # Heavy shake on KO

	var winner_name: String = ""
	var winner_is_p1: bool = false
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_defeated:
			winner_name = player.display_name
			winner_is_p1 = (player == $Player)
			break

	if winner_is_p1:
		p1_wins += 1
	else:
		p2_wins += 1

	_update_wins_display()

	if p1_wins >= 2 or p2_wins >= 2:
		win_label.text = winner_name + " Wins!"
		win_screen.visible = true
		yield(get_tree().create_timer(2.0), "timeout")
		get_tree().change_scene("res://scenes/CharacterSelect.tscn")
	else:
		win_label.text = winner_name + " wins Round %d!" % current_round
		win_screen.visible = true
		yield(get_tree().create_timer(2.0), "timeout")
		win_screen.visible = false
		current_round += 1
		$Player.reset_for_round()
		$Player2.reset_for_round()
		_start_round()

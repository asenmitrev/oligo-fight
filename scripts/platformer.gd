extends Node2D

export var simonka_frames: SpriteFrames
export var georgi_frames: SpriteFrames

onready var win_screen: ColorRect = $HUD/WinScreen
onready var win_label: Label = $HUD/WinScreen/WinLabel
onready var countdown_label: Label = $HUD/CountdownLabel
onready var p1_wins_label: Label = $HUD/P1WinsLabel
onready var p2_wins_label: Label = $HUD/P2WinsLabel

var p1_wins: int = 0
var p2_wins: int = 0
var current_round: int = 1
var round_in_progress: bool = false

var _pause_menu: CanvasLayer
var _is_paused: bool = false
var _was_round_in_progress: bool = false

func _ready() -> void:
	_build_pause_menu()
	_apply_character_selections()
	for player in get_tree().get_nodes_in_group("players"):
		player.connect("defeated", self, "_on_player_defeated")
	_update_wins_display()
	call_deferred("_setup_countdown_scale")
	_start_round()

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

	var char_btn = Button.new()
	char_btn.text = "Character Select"
	char_btn.connect("pressed", self, "_on_pause_character_select")
	vbox.add_child(char_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.connect("pressed", self, "_on_pause_quit")
	vbox.add_child(quit_btn)

	_pause_menu.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _is_paused:
			_resume_game()
		else:
			_pause_game()

func _pause_game() -> void:
	_is_paused = true
	_was_round_in_progress = round_in_progress
	_set_players_frozen(true)
	_pause_menu.visible = true

func _resume_game() -> void:
	_is_paused = false
	_pause_menu.visible = false
	if _was_round_in_progress:
		_set_players_frozen(false)

func _on_pause_character_select() -> void:
	_is_paused = false
	get_tree().change_scene("res://scenes/CharacterSelect.tscn")

func _on_pause_quit() -> void:
	get_tree().quit()

func _setup_countdown_scale() -> void:
	countdown_label.rect_pivot_offset = countdown_label.rect_size / 2.0
	countdown_label.rect_scale = Vector2(5.0, 5.0)

func _apply_character_selections() -> void:
	_configure_player($Player, GameState.p1_character)
	_configure_player($Player2, GameState.p2_character)

func _configure_player(player: KinematicBody2D, char_name: String) -> void:
	player.display_name = char_name
	var anim: AnimatedSprite = player.get_node("AnimatedSprite")
	if char_name == "Georgi":
		anim.frames = georgi_frames
		anim.modulate = Color(1, 1, 1, 1)
	elif char_name == "Evil Simonka":
		anim.frames = simonka_frames
		anim.modulate = Color(1, 0.75, 0.85, 1)
	else:
		anim.frames = simonka_frames
		anim.modulate = Color(1, 1, 1, 1)
	anim.play("idle")

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
	_set_players_frozen(true)
	countdown_label.visible = true
	countdown_label.text = "Round %d" % current_round
	yield(get_tree().create_timer(1.2), "timeout")
	for i in range(3, 0, -1):
		countdown_label.text = str(i)
		yield(get_tree().create_timer(1.0), "timeout")
	countdown_label.text = "FIGHT!"
	yield(get_tree().create_timer(0.6), "timeout")
	countdown_label.visible = false
	round_in_progress = true
	_set_players_frozen(false)

func _on_player_defeated() -> void:
	if not round_in_progress:
		return
	round_in_progress = false
	_set_players_frozen(true)

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

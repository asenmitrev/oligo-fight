extends Node2D

const FIGHT_BACKGROUNDS := [
	"res://assets/bg.png",
	"res://assets/bg2.png",
	"res://assets/bg3.png",
	"res://assets/bg4.png",
]

const FIGHT_MUSIC := [
	preload("res://assets/music/thrift-shop.ogg"),
	preload("res://assets/music/cinema.ogg"),
	preload("res://assets/music/picnic.ogg"),
	preload("res://assets/music/bar.ogg"),
]

onready var _music: AudioStreamPlayer = $Music
onready var win_screen: ColorRect = $HUD/WinScreen
onready var win_label: Label = $HUD/WinScreen/WinLabel
onready var p1_wins_label: Label = $HUD/P1WinsLabel
onready var p2_wins_label: Label = $HUD/P2WinsLabel
onready var camera: Camera2D = $Camera2D
onready var _p1: KinematicBody2D = $Player
onready var _p2: KinematicBody2D = $Player2

var p1_wins: int = 0
var p2_wins: int = 0
var current_round: int = 1
var round_in_progress: bool = false

# Win circles HUD
var _p1_circles: Array = []       # TextureRect nodes
var _p2_circles: Array = []
var _win_tween: Tween
const CIRCLE_SIZE := 26
const CIRCLE_GAP := 10

var _pause_menu: CanvasLayer
var _pause_char_btn: Button
var _pause_quit_btn: Button
var _is_paused: bool = false
var _was_round_in_progress: bool = false
# Captured at frame start so _input can detect "just pressed" and avoid
# double-toggle when the same physical button fires through multiple
# InputMap entries (RetroPie / ControllerMapper issue).
var _pause_action_was_pressed: bool = false

# Camera Shake
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _camera_origin: Vector2
var _shake_tick: int = 0

# Pre-computed pseudo-random shake offsets (120 entries = 4 seconds at 30fps)
# Generated once at startup, no sin/cos per frame on Pi 3
const _SHAKE_TABLE_SIZE := 120
var _shake_table_x: Array = []
var _shake_table_y: Array = []

# Combo HUD
var _p1_combo_root: Control = null
var _p2_combo_root: Control = null
var _p1_combo_label: Label = null
var _p2_combo_label: Label = null
var _p1_combo_timer: float = 0.0
var _p2_combo_timer: float = 0.0
const COMBO_DISPLAY_DURATION := 2.5
const COMBO_FADE_START := 1.0

var LOBSTER_FONT: BitmapFont = load("res://assets/fonts/lobster52.fnt")
var LOBSTER_FONT_28: BitmapFont = load("res://assets/fonts/lobster28.fnt")

# Whataboutism HUD
var _whataboutism_node: Control = null
var _whataboutism_timer: float = 0.0
const WHATABOUTISM_DISPLAY_DURATION := 2.0
const WHATABOUTISM_FADE_START := 0.8

func _ready() -> void:
	assert(FIGHT_BACKGROUNDS.size() == GameState.FIGHT_BACKGROUND_COUNT)
	_apply_fight_background()
	_setup_health_bars()
	_build_pause_menu()
	_apply_character_selections()
	_p1.set_opponent(_p2)
	_p2.set_opponent(_p1)
	_camera_origin = camera.position
	_init_shake_table()
	
	_p1.connect("defeated", self, "_on_player_defeated")
	_p1.connect("hit_landed", self, "_on_p1_hit_landed")
	_p1.connect("whataboutism_triggered", self, "_on_whataboutism")
	_p2.connect("defeated", self, "_on_player_defeated")
	_p2.connect("hit_landed", self, "_on_p2_hit_landed")
	_p2.connect("whataboutism_triggered", self, "_on_whataboutism")

	_setup_combo_labels()
	_setup_win_circles()
	_update_wins_display()

	_start_round()

	var music_idx: int = int(clamp(GameState.fight_background_index, 0, FIGHT_MUSIC.size() - 1))
	var stream: AudioStreamOGGVorbis = FIGHT_MUSIC[music_idx]
	stream.loop = true
	_music.stream = stream
	_music.play()

func _init_shake_table() -> void:
	# Fill lookup table with pseudo-random normalized offsets
	for i in range(_SHAKE_TABLE_SIZE):
		_shake_table_x.append(randf() * 2.0 - 1.0)
		_shake_table_y.append(randf() * 2.0 - 1.0)

func _setup_health_bars() -> void:
	var p1_bar = $HUD/P1HealthBar
	var p2_bar = $HUD/P2HealthBar
	
	# Common styles
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.border_width_left = 3
	bg_style.border_width_right = 3
	bg_style.border_width_top = 3
	bg_style.border_width_bottom = 3
	bg_style.border_color = Color(0.2, 0.2, 0.2)
	bg_style.expand_margin_left = 2
	bg_style.expand_margin_right = 2
	bg_style.expand_margin_top = 2
	bg_style.expand_margin_bottom = 2
	
	# P1 Fill Style
	var p1_fg = StyleBoxFlat.new()
	p1_fg.bg_color = GameState.P1_COLOR
	p1_fg.border_width_left = 2
	p1_fg.border_width_right = 2
	p1_fg.border_width_top = 2
	p1_fg.border_width_bottom = 2
	p1_fg.border_color = Color(1, 1, 1, 0.5) # Slight highlight
	
	# P2 Fill Style
	var p2_fg = StyleBoxFlat.new()
	p2_fg.bg_color = GameState.P2_COLOR
	p2_fg.border_width_left = 2
	p2_fg.border_width_right = 2
	p2_fg.border_width_top = 2
	p2_fg.border_width_bottom = 2
	p2_fg.border_color = Color(1, 1, 1, 0.5) # Slight highlight
	
	p1_bar.add_stylebox_override("bg", bg_style)
	p1_bar.add_stylebox_override("fg", p1_fg)
	p2_bar.add_stylebox_override("bg", bg_style)
	p2_bar.add_stylebox_override("fg", p2_fg)
	
	# Make them taller (shadow dropped — extra fragment work each frame on Pi 3)
	p1_bar.margin_bottom = p1_bar.margin_top + 44
	p2_bar.margin_bottom = p2_bar.margin_top + 44
	
	# Add name labels above bars
	var p1_name = Label.new()
	p1_name.text = GameState.p1_character
	p1_name.rect_position = Vector2(p1_bar.rect_position.x, p1_bar.rect_position.y - 25)
	p1_name.add_font_override("font", LOBSTER_FONT_28)
	p1_name.add_color_override("font_color", Color.white)
	$HUD.add_child(p1_name)
	
	var p2_name = Label.new()
	p2_name.text = GameState.p2_character
	p2_name.align = Label.ALIGN_RIGHT
	p2_name.rect_position = Vector2(p2_bar.rect_position.x, p2_bar.rect_position.y - 25)
	p2_name.rect_size.x = p2_bar.rect_size.x
	p2_name.add_font_override("font", LOBSTER_FONT_28)
	p2_name.add_color_override("font_color", Color.white)
	$HUD.add_child(p2_name)
	
	# Wins display is handled by circle nodes built in _setup_win_circles()
	p1_wins_label.visible = false
	p2_wins_label.visible = false

func _process(delta: float) -> void:
	# Capture pause/start action state at frame start so _input can detect
	# "just pressed" and avoid double-toggle on RetroPie.
	_pause_action_was_pressed = Input.is_action_pressed("pause") or Input.is_action_pressed("start")

	if _shake_duration <= 0 and _p1_combo_timer <= 0.0 and _p2_combo_timer <= 0.0 and _whataboutism_timer <= 0.0:
		return
	
	if _shake_duration > 0:
		_shake_duration -= delta
		_shake_tick = (_shake_tick + 1) % _SHAKE_TABLE_SIZE
		var offset = Vector2(
			_shake_table_x[_shake_tick] * _shake_intensity,
			_shake_table_y[_shake_tick] * _shake_intensity
		)
		camera.position = _camera_origin + offset
		if _shake_duration <= 0:
			camera.position = _camera_origin
			_shake_tick = 0

	_p1_combo_timer = max(0.0, _p1_combo_timer - delta)
	_p2_combo_timer = max(0.0, _p2_combo_timer - delta)
	if _p1_combo_root:
		_tick_combo_label(_p1_combo_root, _p1_combo_timer, delta)
	if _p2_combo_root:
		_tick_combo_label(_p2_combo_root, _p2_combo_timer, delta)

	if _whataboutism_timer > 0.0:
		_whataboutism_timer = max(0.0, _whataboutism_timer - delta)
		if _whataboutism_node:
			_whataboutism_node.rect_scale = _whataboutism_node.rect_scale.linear_interpolate(Vector2(1.0, 1.0), delta * 10.0)
			if _whataboutism_timer < WHATABOUTISM_FADE_START:
				_whataboutism_node.modulate.a = _whataboutism_timer / WHATABOUTISM_FADE_START
			if _whataboutism_timer == 0.0:
				_whataboutism_node.modulate.a = 0.0

func shake_camera(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration

func _on_p1_hit_landed(is_heavy: bool, combo_count: int) -> void:
	if is_heavy:
		shake_camera(8.0, 0.15)
	else:
		shake_camera(3.0, 0.1)
	if combo_count >= 2:
		_show_combo(_p1_combo_root, _p1_combo_label, combo_count, _p1, _p2)
		_p1_combo_timer = COMBO_DISPLAY_DURATION

func _on_p2_hit_landed(is_heavy: bool, combo_count: int) -> void:
	if is_heavy:
		shake_camera(8.0, 0.15)
	else:
		shake_camera(3.0, 0.1)
	if combo_count >= 2:
		_show_combo(_p2_combo_root, _p2_combo_label, combo_count, _p2, _p1)
		_p2_combo_timer = COMBO_DISPLAY_DURATION

func _on_whataboutism() -> void:
	shake_camera(10.0, 0.25)
	if _whataboutism_node == null:
		_setup_whataboutism()
	_whataboutism_timer = WHATABOUTISM_DISPLAY_DURATION
	_whataboutism_node.modulate.a = 1.0
	_whataboutism_node.rect_scale = Vector2(1.4, 1.4)

func _setup_whataboutism() -> void:
	var tex = load("res://assets/rado/whatabaoutism.png") as Texture
	var vp_size = get_viewport().size
	var img_size = Vector2(280, 280)
	_whataboutism_node = Control.new()
	_whataboutism_node.rect_size = img_size
	_whataboutism_node.rect_position = vp_size / 2.0 - img_size / 2.0
	_whataboutism_node.modulate.a = 0.0
	var img = TextureRect.new()
	img.texture = tex
	img.expand = true
	img.rect_size = img_size
	_whataboutism_node.add_child(img)
	$HUD.add_child(_whataboutism_node)

func _setup_combo_labels() -> void:
	var combo_tex = load("res://assets/combo.png")

	_p1_combo_root = _make_combo_widget(combo_tex)
	_p1_combo_label = _p1_combo_root.get_child(1)
	$HUD.add_child(_p1_combo_root)

	_p2_combo_root = _make_combo_widget(combo_tex)
	_p2_combo_label = _p2_combo_root.get_child(1)
	$HUD.add_child(_p2_combo_root)

func _make_combo_widget(tex: Texture) -> Control:
	var root = Control.new()
	root.rect_position = Vector2(0, 0)
	root.rect_size = Vector2(150, 90)
	root.modulate.a = 0.0

	var img = TextureRect.new()
	img.texture = tex
	img.expand = true
	img.rect_position = Vector2(0, 0)
	img.rect_size = Vector2(90, 90)
	root.add_child(img)

	var lbl = Label.new()
	lbl.add_font_override("font", LOBSTER_FONT_28)
	lbl.rect_position = Vector2(95, 0)
	lbl.rect_size = Vector2(55, 90)
	lbl.valign = Label.VALIGN_CENTER
	lbl.align = Label.ALIGN_LEFT
	lbl.modulate = Color(1, 1, 1, 1)
	root.add_child(lbl)

	return root

func _update_combo_pos(root: Control, attacker: KinematicBody2D, opponent: KinematicBody2D) -> void:
	var screen_pos = get_viewport().get_canvas_transform().xform(attacker.global_position)
	var to_opponent = opponent.global_position.x - attacker.global_position.x
	var x: float
	if to_opponent > 0:
		# Opponent is to the right — place widget to the left of attacker
		x = screen_pos.x - 160
	else:
		# Opponent is to the left — place widget to the right of attacker
		x = screen_pos.x + 10
	var y = screen_pos.y - 80
	root.rect_position = Vector2(clamp(x, 0, 490), clamp(y, 0, 270))

func _show_combo(root: Control, label: Label, count: int, attacker: KinematicBody2D, opponent: KinematicBody2D) -> void:
	label.text = str(count)
	_update_combo_pos(root, attacker, opponent)
	root.modulate.a = 1.0
	root.rect_scale = Vector2(1.3, 1.3)

func _tick_combo_label(root: Control, t: float, delta: float) -> void:
	if t <= 0.0:
		root.modulate.a = 0.0
		return
	root.rect_scale = root.rect_scale.linear_interpolate(Vector2(1.0, 1.0), delta * 12.0)
	if t < COMBO_FADE_START:
		root.modulate.a = t / COMBO_FADE_START
	else:
		root.modulate.a = 1.0

func _apply_fight_background() -> void:
	var idx: int = int(clamp(
			GameState.fight_background_index,
			0,
			FIGHT_BACKGROUNDS.size() - 1))
	$BgLayer/Background.texture = load(FIGHT_BACKGROUNDS[idx])

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
	panel.anchor_left = 0.25
	panel.anchor_right = 0.75
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
	title.add_font_override("font", LOBSTER_FONT_28)
	title.add_color_override("font_color", Color.white)
	vbox.add_child(title)

	_pause_char_btn = Button.new()
	_pause_char_btn.text = "Character Select"
	_pause_char_btn.add_font_override("font", LOBSTER_FONT_28)
	_pause_char_btn.connect("pressed", self, "_on_pause_character_select")
	vbox.add_child(_pause_char_btn)

	_pause_quit_btn = Button.new()
	_pause_quit_btn.text = "Quit Game"
	_pause_quit_btn.add_font_override("font", LOBSTER_FONT_28)
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
	# Check if this event triggers pause or start
	var wants_pause := event.is_action_pressed("pause") or event.is_action_pressed("start")
	if not wants_pause:
		return

	# Guard: only toggle when the action transitions from released -> pressed.
	# _pause_action_was_pressed was captured at frame start in _process, so
	# if it's still false here this is the first event of the press.
	# This prevents double-toggle on RetroPie where ControllerMapper can route
	# the same physical button through multiple InputMap entries.
	if _pause_action_was_pressed:
		get_viewport().set_input_as_handled()
		return

	if _is_paused:
		_resume_game()
	else:
		_pause_game()

	get_viewport().set_input_as_handled()

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
	_music.stream_paused = true

func _resume_game() -> void:
	_is_paused = false
	_pause_menu.visible = false
	if _pause_char_btn.has_focus():
		_pause_char_btn.release_focus()
	elif _pause_quit_btn.has_focus():
		_pause_quit_btn.release_focus()
	if _was_round_in_progress:
		_set_players_frozen(false)
	_music.stream_paused = false

func _on_pause_character_select() -> void:
	_is_paused = false
	_music.stop()
	get_tree().change_scene("res://scenes/CharacterSelect.tscn")

func _on_pause_quit() -> void:
	_music.stop()
	get_tree().quit()

func _apply_character_selections() -> void:
	_configure_player(_p1, GameState.p1_character, false)
	_configure_player(_p2, GameState.p2_character, GameState.p2_is_mirror)

func _configure_player(player: KinematicBody2D, char_name: String, is_mirror: bool) -> void:
	var def = CharacterDB.get_by_display_name(char_name)
	if def == null:
		def = CharacterDB.all_characters[0]
	
	player.set_script(preload("res://scripts/player.gd"))

	player.apply_character(def)
	
	if is_mirror:
		player.anim.modulate = Color(1, 0.75, 0.85, 1)

func _setup_win_circles() -> void:
	var circle_tex := load("res://assets/win_circle.png") as Texture

	# P1 circles – anchored to left side under health bar
	var p1_hbox := HBoxContainer.new()
	p1_hbox.anchor_left = 0.0
	p1_hbox.anchor_right = 0.0
	p1_hbox.anchor_top = 0.0
	p1_hbox.anchor_bottom = 0.0
	p1_hbox.margin_left = 20
	p1_hbox.margin_top = 62
	p1_hbox.margin_right = 20 + 2 * CIRCLE_SIZE + CIRCLE_GAP
	p1_hbox.margin_bottom = 62 + CIRCLE_SIZE
	p1_hbox.add_constant_override("separation", CIRCLE_GAP)
	$HUD.add_child(p1_hbox)

	for _i in range(2):
		var tr := TextureRect.new()
		tr.texture = circle_tex
		tr.rect_min_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
		tr.expand = true
		tr.modulate = Color(0.35, 0.35, 0.35, 1.0) # empty = dim gray
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p1_hbox.add_child(tr)
		_p1_circles.append(tr)

	# P2 circles – anchored to right side
	var p2_hbox := HBoxContainer.new()
	p2_hbox.anchor_left = 1.0
	p2_hbox.anchor_right = 1.0
	p2_hbox.anchor_top = 0.0
	p2_hbox.anchor_bottom = 0.0
	p2_hbox.margin_right = -20
	p2_hbox.margin_left = -(20 + 2 * CIRCLE_SIZE + CIRCLE_GAP)
	p2_hbox.margin_top = 62
	p2_hbox.margin_bottom = 62 + CIRCLE_SIZE
	p2_hbox.add_constant_override("separation", CIRCLE_GAP)
	p2_hbox.alignment = BoxContainer.ALIGN_END
	$HUD.add_child(p2_hbox)

	for _i in range(2):
		var tr := TextureRect.new()
		tr.texture = circle_tex
		tr.rect_min_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
		tr.expand = true
		tr.modulate = Color(0.35, 0.35, 0.35, 1.0) # empty = dim gray
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p2_hbox.add_child(tr)
		_p2_circles.append(tr)

	_win_tween = Tween.new()
	add_child(_win_tween)

func _set_circle_filled(circle: TextureRect, filled: bool) -> void:
	circle.modulate = Color(1, 1, 1, 1) if filled else Color(0.35, 0.35, 0.35, 1.0)

func _flash_circle(circle: TextureRect) -> void:
	circle.modulate = Color(3.0, 3.0, 3.0, 1.0)
	_win_tween.interpolate_property(circle, "modulate",
		Color(3.0, 3.0, 3.0, 1.0), Color(1.0, 1.0, 1.0, 1.0),
		0.9, Tween.TRANS_SINE, Tween.EASE_OUT)
	_win_tween.start()

func _update_wins_display() -> void:
	for i in range(2):
		_set_circle_filled(_p1_circles[i], i < p1_wins)
		_set_circle_filled(_p2_circles[i], i < p2_wins)

func _set_players_frozen(frozen: bool) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		player.frozen = frozen

func _set_players_input_disabled(disabled: bool) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		player.input_disabled = disabled

func _start_round() -> void:
	round_in_progress = true
	_set_players_frozen(false)

func _on_player_defeated() -> void:
	if not round_in_progress:
		return
	round_in_progress = false
	_set_players_frozen(true)
	_set_players_input_disabled(true)
	shake_camera(15.0, 0.5) # Heavy shake on KO
	_p1_combo_timer = 0.0
	_p2_combo_timer = 0.0

	var winner_name: String = ""
	var loser_name: String = ""
	var winner_is_p1: bool = false
	var winner = null
	var loser = null
	
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_defeated:
			winner = player
			winner_name = player.display_name
			winner_is_p1 = (player == _p1)
		else:
			loser = player
			loser_name = player.display_name

	if winner_is_p1:
		p1_wins += 1
	else:
		p2_wins += 1

	_update_wins_display()
	if winner_is_p1:
		_flash_circle(_p1_circles[p1_wins - 1])
	else:
		_flash_circle(_p2_circles[p2_wins - 1])

	var veli_beat_simonka: bool = winner_name == "Veli" and loser_name == "Simonka"
	var win_text: String = "Veli thinks he's won!" if veli_beat_simonka else winner_name + " Wins!"
	var round_text: String = "Veli thinks he's won Round %d!" % current_round if veli_beat_simonka else winner_name + " wins Round %d!" % current_round

	if veli_beat_simonka:
		win_label.text = win_text
		win_screen.visible = true

		yield(get_tree().create_timer(1.0), "timeout")

		# Simonka stands back up
		loser.frozen = false
		loser.anim.flip_h = winner.global_position.x < loser.global_position.x
		loser.force_getup()
		yield(get_tree().create_timer(0.8), "timeout")

		# If they are close, she hits him
		var dist = winner.global_position.distance_to(loser.global_position)
		winner.frozen = false # Unfreeze winner too so he can fall
		winner.stay_down = true # Ensure he stays on the ground
		if dist < 220:
			loser.force_punch()
			yield(get_tree().create_timer(0.3), "timeout")
			winner.force_fall()
		else:
			winner.force_fall()

		yield(get_tree().create_timer(1.0), "timeout")
	else:
		if p1_wins >= 2 or p2_wins >= 2:
			win_label.text = win_text
			win_screen.visible = true
			yield(get_tree().create_timer(2.0), "timeout")
		else:
			win_label.text = round_text
			win_screen.visible = true
			yield(get_tree().create_timer(2.0), "timeout")

	if p1_wins >= 2 or p2_wins >= 2:
		get_tree().change_scene("res://scenes/CharacterSelect.tscn")
	else:
		win_screen.visible = false
		current_round += 1
		_p1.reset_for_round()
		_p2.reset_for_round()
		_p1.set_opponent(_p2)
		_p2.set_opponent(_p1)
		_start_round()

extends Node2D

const FIGHT_BACKGROUNDS := [
	"res://assets/bg.png",
	"res://assets/bg2.png",
	"res://assets/bg3.png",
	"res://assets/bg4.png",
]

const FIGHT_MUSIC := [
	"res://assets/music/thrift-shop.mp3",
	"res://assets/music/cinema.mp3",
	"res://assets/music/picnic.mp3",
	"res://assets/music/bar.mp3",
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

# Online mode
var is_online: bool = false
var _local_role: String = ""
var _local_player: KinematicBody2D = null
var _remote_player: KinematicBody2D = null
var _real_frame: int = 0   # Increments every physics tick (always advances)
var _exec_frame: int = 0   # Next game frame to execute (advances only when both inputs available)
var _is_stalled: bool = false
var _stall_frames: int = 0  # Counts consecutive frames stalled; triggers disconnect after timeout

# Win circles HUD
var _p1_circles: Array = []       # Panel nodes
var _p2_circles: Array = []
var _p1_circle_styles: Array = [] # StyleBoxFlat refs
var _p2_circle_styles: Array = []
var _win_tween: Tween
const CIRCLE_SIZE := 26
const CIRCLE_GAP := 10

var _pause_menu: CanvasLayer
var _pause_char_btn: Button
var _pause_quit_btn: Button
var _is_paused: bool = false
var _was_round_in_progress: bool = false

# Camera Shake
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _camera_origin: Vector2

# Combo HUD
var _p1_combo_root: Control = null
var _p2_combo_root: Control = null
var _p1_combo_label: Label = null
var _p2_combo_label: Label = null
var _p1_combo_timer: float = 0.0
var _p2_combo_timer: float = 0.0
const COMBO_DISPLAY_DURATION := 2.5
const COMBO_FADE_START := 1.0

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
	_camera_origin = camera.position
	
	_p1.connect("defeated", self, "_on_player_defeated")
	_p1.connect("hit_landed", self, "_on_p1_hit_landed")
	_p1.connect("special_combo_triggered", self, "_on_special_combo")
	_p1.connect("whataboutism_triggered", self, "_on_whataboutism")
	_p2.connect("defeated", self, "_on_player_defeated")
	_p2.connect("hit_landed", self, "_on_p2_hit_landed")
	_p2.connect("special_combo_triggered", self, "_on_special_combo")
	_p2.connect("whataboutism_triggered", self, "_on_whataboutism")

	_setup_combo_labels()
	_setup_win_circles()
	_update_wins_display()

	if GameState.is_online:
		_setup_online()

	_start_round()

	var music_idx: int = int(clamp(GameState.fight_background_index, 0, FIGHT_MUSIC.size() - 1))
	var stream := load(FIGHT_MUSIC[music_idx]) as AudioStreamMP3
	stream.loop = true
	_music.stream = stream
	_music.play()

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
	
	# Make them taller and add shadow
	p1_bar.margin_bottom = p1_bar.margin_top + 44
	p2_bar.margin_bottom = p2_bar.margin_top + 44
	
	bg_style.shadow_color = Color(0, 0, 0, 0.5)
	bg_style.shadow_size = 4
	bg_style.shadow_offset = Vector2(2, 2)
	
	# Add name labels above bars
	var p1_name = Label.new()
	p1_name.text = GameState.p1_character
	p1_name.rect_position = Vector2(p1_bar.rect_position.x, p1_bar.rect_position.y - 25)
	$HUD.add_child(p1_name)
	
	var p2_name = Label.new()
	p2_name.text = GameState.p2_character
	p2_name.align = Label.ALIGN_RIGHT
	p2_name.rect_position = Vector2(p2_bar.rect_position.x, p2_bar.rect_position.y - 25)
	p2_name.rect_size.x = p2_bar.rect_size.x
	$HUD.add_child(p2_name)
	
	# Wins display is handled by circle nodes built in _setup_win_circles()
	p1_wins_label.visible = false
	p2_wins_label.visible = false

func _physics_process(_delta: float) -> void:
	if is_online:
		_process_online_frame()


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

	_p1_combo_timer = max(0.0, _p1_combo_timer - delta)
	_p2_combo_timer = max(0.0, _p2_combo_timer - delta)
	if _p1_combo_root:
		_tick_combo_label(_p1_combo_root, _p1_combo_timer, delta)
		if _p1_combo_timer > 0.0:
			_update_combo_pos(_p1_combo_root, _p1, _p2)
	if _p2_combo_root:
		_tick_combo_label(_p2_combo_root, _p2_combo_timer, delta)
		if _p2_combo_timer > 0.0:
			_update_combo_pos(_p2_combo_root, _p2, _p1)

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
		_show_combo(_p1_combo_root, _p1_combo_label, combo_count)
		_p1_combo_timer = COMBO_DISPLAY_DURATION

func _on_p2_hit_landed(is_heavy: bool, combo_count: int) -> void:
	if is_heavy:
		shake_camera(8.0, 0.15)
	else:
		shake_camera(3.0, 0.1)
	if combo_count >= 2:
		_show_combo(_p2_combo_root, _p2_combo_label, combo_count)
		_p2_combo_timer = COMBO_DISPLAY_DURATION

func _on_special_combo() -> void:
	shake_camera(12.0, 0.3)

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
	var font_data = DynamicFontData.new()
	font_data.font_path = "res://assets/fonts/Lobster-Regular.ttf"
	var font = DynamicFont.new()
	font.font_data = font_data
	font.size = 28
	font.outline_size = 4
	font.outline_color = Color(0, 0, 0, 1)

	var combo_tex = load("res://assets/combo.png")

	_p1_combo_root = _make_combo_widget(combo_tex, font)
	_p1_combo_label = _p1_combo_root.get_child(1)
	$HUD.add_child(_p1_combo_root)

	_p2_combo_root = _make_combo_widget(combo_tex, font)
	_p2_combo_label = _p2_combo_root.get_child(1)
	$HUD.add_child(_p2_combo_root)

func _make_combo_widget(tex: Texture, font: DynamicFont) -> Control:
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
	lbl.add_font_override("font", font)
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

func _show_combo(root: Control, label: Label, count: int) -> void:
	label.text = str(count)
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

func _setup_online() -> void:
	is_online = true
	_local_role = NetworkManager.local_role
	_local_player = _p1 if _local_role == "p1" else _p2
	_remote_player = _p2 if _local_role == "p1" else _p1
	_local_player.is_networked = true
	_remote_player.is_networked = true
	_reset_online_state()
	NetworkManager.connect("opponent_disconnected", self, "_on_opponent_disconnected")

func _reset_online_state() -> void:
	NetworkManager.remote_input_buffer.clear()
	NetworkManager.local_input_buffer.clear()
	NetworkManager.remote_state_hash_buffer.clear()
	_real_frame = 0
	_exec_frame = 0
	_is_stalled = false
	_stall_frames = 0


func _state_hash() -> int:
	var s := ""
	for p in [_p1, _p2]:
		s += "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d;" % [
			int(round(p.global_position.x)), int(round(p.global_position.y)),
			p.health, p.state as int,
			p._knockback_x, p._hitstop_ticks, p._hit_ticks, p._block_stun_ticks,
			p._anim_ticks_remaining,
			1 if p._attacking else 0,
			1 if p._anim_hit_fired else 0,
			p._attack_tick_count, p._attack_hit_tick
		]
		for i in range(p._proj_pool):
			s += "%d,%d,%d;" % [
				1 if p._proj_active[i] else 0,
				p._proj_x[i], p._proj_lifetime[i]
			]
		s += "%d,%d,%d;" % [
			1 if p._proj_launch_fired else 0,
			p._proj_launch_tick, p._proj_launch_count
		]
	return s.hash()


func _print_state_detail(label: String) -> void:
	print("[%s exec=%d]" % [label, _exec_frame])
	for p in [_p1, _p2]:
		print("  %s pos=(%d,%d) hp=%d st=%d kb=%d hs=%d ht=%d bs=%d rem=%d atk=%s fired=%s cnt=%d htick=%d proj=%s(%d,%d)" % [
			p.display_name,
			int(round(p.global_position.x)), int(round(p.global_position.y)),
			p.health, p.state as int,
			p._knockback_x, p._hitstop_ticks, p._hit_ticks, p._block_stun_ticks,
			p._anim_ticks_remaining,
			str(p._attacking), str(p._anim_hit_fired),
			p._attack_tick_count, p._attack_hit_tick,
			str(p._proj_active), p._proj_x, p._proj_y
		])


func _process_online_frame() -> void:
	var delay := NetworkManager.input_delay_frames

	# Compute state hash and send with local input for this real-time frame.
	# The hash represents state BEFORE this exec_frame (i.e. after exec_frame-1).
	# We use real_frame as the index — both machines advance real_frame in lockstep.
	var my_hash := _state_hash()
	var local_keys := _sample_local_input()
	NetworkManager.local_input_buffer[_real_frame] = local_keys
	NetworkManager.send_input_frame(_real_frame, local_keys, my_hash)

	# Compare our hash with the remote's hash for the same real_frame.
	# Both machines should have identical state at the same real_frame when in sync.
	if NetworkManager.remote_state_hash_buffer.has(_real_frame):
		var remote_hash: int = NetworkManager.remote_state_hash_buffer[_real_frame]
		if remote_hash != my_hash:
			print("[DESYNC detected at real_frame=%d exec_frame=%d]" % [_real_frame, _exec_frame])
			_print_state_detail("LOCAL")

	_real_frame += 1

	# Wait until we have buffered enough frames to start executing
	if _real_frame <= delay:
		return

	# Check if remote input for the next execute frame has arrived
	if not NetworkManager.remote_input_buffer.has(_exec_frame):
		if round_in_progress:
			if not _is_stalled:
				_is_stalled = true
				_set_players_frozen(true)
			_stall_frames += 1
			# 10 seconds at 60 fps — silent disconnect fallback
			if _stall_frames >= 600:
				print("[Fight] Stall timeout: no remote input for exec_frame=%d after 10s, treating as disconnect" % _exec_frame)
				_on_opponent_disconnected()
				return
		return

	# Remote input arrived — unstall if needed
	if _is_stalled:
		_is_stalled = false
		_stall_frames = 0
		if round_in_progress:
			_set_players_frozen(false)

	# Apply both players' committed inputs for this game frame
	var local_exec: int = NetworkManager.local_input_buffer.get(_exec_frame, 0)
	var remote_exec: int = NetworkManager.remote_input_buffer[_exec_frame]
	_local_player.set_committed_keys(local_exec)
	_remote_player.set_committed_keys(remote_exec)

	_exec_frame += 1


func _sample_local_input() -> int:
	var prefix := "p1_"
	var keys := 0
	if Input.is_action_pressed(prefix + "left"):       keys |= 1
	if Input.is_action_pressed(prefix + "right"):      keys |= 2
	if Input.is_action_just_pressed(prefix + "jump"):  keys |= 4
	if Input.is_action_pressed(prefix + "down"):       keys |= 8
	if Input.is_action_just_pressed(prefix + "punch"): keys |= 16
	if Input.is_action_just_pressed(prefix + "kick"):  keys |= 32
	return keys


func _on_opponent_disconnected() -> void:
	_set_players_frozen(true)
	round_in_progress = false
	win_label.text = "Opponent disconnected"
	win_screen.visible = true
	yield(get_tree().create_timer(3.0), "timeout")
	_music.stop()
	get_tree().change_scene("res://scenes/MainMenu.tscn")


func _apply_fight_background() -> void:
	var idx: int = int(clamp(
			GameState.fight_background_index,
			0,
			FIGHT_BACKGROUNDS.size() - 1))
	$Background.texture = load(FIGHT_BACKGROUNDS[idx])

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
	if is_online:
		NetworkManager.disconnect_from_server()
		GameState.is_online = false
		get_tree().change_scene("res://scenes/MainMenu.tscn")
	else:
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
	
	# Save exported variables before script swap
	var actions = {
		"left": player.action_left,
		"right": player.action_right,
		"jump": player.action_jump,
		"down": player.action_down,
		"punch": player.action_punch,
		"kick": player.action_kick,
		"face_left": player.face_left,
		"hb_path": player.health_bar_path,
		"dname": player.display_name
	}

	# Performance Optimization for Raspberry Pi:
	if def.fires_projectile:
		player.set_script(preload("res://scripts/shooter_player.gd"))
	elif def.whataboutism_blocks or def.punch_makes_invisible or def.invulnerable_when_airborne:
		player.set_script(preload("res://scripts/special_player.gd"))
	else:
		player.set_script(preload("res://scripts/player.gd"))
	
	# Restore exported variables
	player.action_left = actions.left
	player.action_right = actions.right
	player.action_jump = actions.jump
	player.action_down = actions.down
	player.action_punch = actions.punch
	player.action_kick = actions.kick
	player.face_left = actions.face_left
	player.health_bar_path = actions.hb_path
	player.display_name = actions.dname

	# After set_script and restoration, re-initialize
	player._ready()
	player.apply_character(def)
	
	if is_mirror:
		player.anim.modulate = Color(1, 0.75, 0.85, 1)

func _setup_win_circles() -> void:
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
		var style := _make_circle_style(false)
		var panel := Panel.new()
		panel.rect_min_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
		panel.add_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p1_hbox.add_child(panel)
		_p1_circles.append(panel)
		_p1_circle_styles.append(style)

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
		var style := _make_circle_style(false)
		var panel := Panel.new()
		panel.rect_min_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
		panel.add_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p2_hbox.add_child(panel)
		_p2_circles.append(panel)
		_p2_circle_styles.append(style)

	_win_tween = Tween.new()
	add_child(_win_tween)

func _make_circle_style(filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var r := CIRCLE_SIZE / 2
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_left = r
	style.corner_radius_bottom_right = r
	if filled:
		style.bg_color = Color(1, 1, 1, 1)
	else:
		style.bg_color = Color(0, 0, 0, 0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1, 1, 1, 0.55)
	return style

func _set_circle_filled(style: StyleBoxFlat, filled: bool) -> void:
	style.bg_color = Color(1, 1, 1, 1) if filled else Color(0, 0, 0, 0)
	var bw := 0 if filled else 2
	style.border_width_left = bw
	style.border_width_right = bw
	style.border_width_top = bw
	style.border_width_bottom = bw

func _flash_circle(panel: Panel) -> void:
	panel.modulate = Color(3.0, 3.0, 3.0, 1.0)
	_win_tween.interpolate_property(panel, "modulate",
		Color(3.0, 3.0, 3.0, 1.0), Color(1.0, 1.0, 1.0, 1.0),
		0.9, Tween.TRANS_SINE, Tween.EASE_OUT)
	_win_tween.start()

func _update_wins_display() -> void:
	for i in range(2):
		_set_circle_filled(_p1_circle_styles[i], i < p1_wins)
		_set_circle_filled(_p2_circle_styles[i], i < p2_wins)

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

	var veli_beat_simonka: bool = (not is_online) and winner_name == "Veli" and loser_name == "Simonka"
	var win_text: String = "Veli thinks he's won!" if veli_beat_simonka else winner_name + " Wins!"
	var round_text: String = "Veli thinks he's won Round %d!" % current_round if veli_beat_simonka else winner_name + " wins Round %d!" % current_round

	if veli_beat_simonka:
		# Special sequence for Veli's "fake" win (offline only — real-time timers would desync online)
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
		if is_online:
			_is_stalled = false
			_stall_frames = 0
		_start_round()

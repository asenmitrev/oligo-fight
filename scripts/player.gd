extends KinematicBody2D

const CharacterDef = preload("res://scripts/character_def.gd")

var speed := 350.0
var jump_velocity := -1700.0
const GRAVITY := 4800.0
const FLOOR_SNAP := Vector2(0, 24)

var punch_damage := 15
var kick_damage := 8
const HIT_COMBO_THRESHOLD := 2
const HIT_WINDOW_TICKS     := 120  # 2.0 s at 60 Hz
const PUNCH_ARM_EXTENSION  := 120.0
const KICK_LEG_EXTENSION   := 150.0
const HIT_TARGET_RADIUS    := 85.0
const KNOCKBACK_FORCE      := 1500.0
const PULL_RANGE           := 350.0
var block_damage_modifier := 0.15
const HITSTOP_TICKS        := 6    # 0.1 s at 60 Hz
const COUNTER_HIT_BONUS    := 1.5
const PROXIMITY_BLOCK_RANGE := 500.0
const BLOCK_STUN_TICKS     := 12   # 0.2 s at 60 Hz
const WALK_BACK_SPEED_MULT := 0.65
const COMBO_INPUT_WINDOW_TICKS := 30  # 0.5 s at 60 Hz
const SPECIAL_COMBO_DAMAGE := 35
const SPECIAL_COMBO_SEQUENCE := ["punch", "punch", "kick"]
var _proj_speed: int = 0
var _proj_damage: int = 10
var _proj_hit_radius: int = 0
var _proj_y_tolerance: int = 0
var _proj_lifetime_ticks: int = 0
var _proj_pool: int = 0
var _proj_spawn_x_offset: int = 70
var _proj_spawn_y_offset: int = 200
var _proj_pending_is_kick: bool = false
var _proj_fires_on_punch: bool = false
var _proj_fires_on_kick: bool = false
var _proj_texture_punch: Texture
var _proj_texture_kick_tex: Texture
var _proj_scale_base: float = 3.0
var _proj_scale_kick: float = 0.0
var _proj_anim_hframes: int = 1
var _proj_anim_vframes: int = 1
var _proj_anim_fps: int = 8
var _proj_kick_upwards: bool = false
var _proj_anim_hframes_kick: int = 1
var _proj_anim_vframes_kick: int = 1
var _proj_anim_fps_kick: int = 8
var _proj_is_kick: Array = []  # bool per slot

export var action_left: String = "p1_left"
# ... (rest of the exports)
export var action_right: String = "p1_right"
export var action_jump: String = "p1_jump"
export var action_down: String = "p1_down"
export var action_punch: String = "p1_punch"
export var action_kick: String = "p1_kick"
export var face_left: bool = false
export var health_bar_path: NodePath
export var display_name: String = "Simonka"

onready var anim: AnimatedSprite = $AnimatedSprite

enum State { NORMAL, HIT, FALLEN, GETUP, BLOCKING }

signal defeated
signal hit_landed(is_heavy, combo_count)
signal special_combo_triggered
signal whataboutism_triggered

var state = State.NORMAL
var max_health := 100
var health := 100
var is_defeated := false
var hit_count := 0
var _hit_ticks: int = 0
var _attacking := false
var _opponent: KinematicBody2D
var _health_bar: ProgressBar
var frozen: bool = false setget _set_frozen
var _punch_arm_extension: float = PUNCH_ARM_EXTENSION
var _start_position: Vector2
var velocity: Vector2 = Vector2.ZERO
var _hitstop_ticks: int = 0
var _knockback_x: int = 0          # integer px/s — no float drift
var _block_stun_ticks: int = 0
var _blocked_punch: bool = false
var _current_anim: String = ""
var launch_punch: bool = false
var combos_enabled: bool = true
var body_punch_enabled: bool = false
var kick_speed_scale: float = 1.0
var punch_speed_scale: float = 1.0
var flykick_speed_scale: float = 1.0
var flypunch_speed_scale: float = 1.0
var kick_lunge_scale: float = 1.0
var punch_lunge_scale: float = 1.0
var kick_heals_self: int = 0
var kick_knockback_multiplier: float = 1.0
var stay_down: bool = false
var input_disabled: bool = false
var fall_gravity_scale: float = 1.0
var invulnerable_when_airborne: bool = false
var partial_loop_jump: bool = false
var punch_pulls_opponent: bool = false
var _input_buffer: Array = []
var _input_buffer_ticks: int = 0
var _current_combo_count: int = 0
var _pending_special: bool = false
var punch_makes_invisible: bool = false
var proj_fires_airborne: bool = false
var whataboutism_blocks: bool = false
var _whataboutism_block_count: int = 0
var _whataboutism_window_ticks: int = 0
var _pending_whataboutism: bool = false
var _pending_whataboutism_pos: Vector2 = Vector2.ZERO
var _pending_whataboutism_damage: int = 0
var _pending_whataboutism_knockback: float = 1.0
var _invis_ticks: int = 0
const INVIS_MAX_TICKS: int = 180  # 3 s at 60 Hz

# Projectile state — fixed-size pool for determinism (ring buffer, newest overwrites oldest)
var fires_projectile: bool = false
var _proj_active: Array = []   # bool per slot
var _proj_x: Array = []        # int per slot
var _proj_y: Array = []        # int per slot
var _proj_vy: Array = []       # int per slot — 0 for horizontal, +speed for 45° downward
var _proj_dir: Array = []      # int per slot
var _proj_lifetime: Array = [] # int per slot
var _proj_next: int = 0        # next slot to write into
var _proj_sprites: Array = []  # Sprite per slot

# Networked input — set by fight.gd each frame in online mode.
var is_networked: bool = false
var _committed_keys: int = 0
var _prev_committed_keys: int = 0
var _action_bits: Dictionary = {}

# Physics-tick hit detection: fires after a fixed tick count from animation FPS.
# Both clients compute the same integer and start from the same exec_frame.
var _anim_hit_fired: bool = false
var _attack_hit_tick: int = -1
var _proj_launch_fired: bool = false
var _proj_launch_tick: int = -1
var _proj_launch_count: int = 0
var _attack_tick_count: int = 0
var _attack_is_kick: bool = false
var _lunge_upwards_kick: bool = false

# Physics-tick animation end detection: replaces the render-loop animation_finished
# signal so state transitions happen at the same exec_frame on both clients.
var _anim_ticks_remaining: int = -1  # -1 = looping or not tracking


func _ready() -> void:
	_start_position = global_position
	add_to_group("players")
	collision_mask |= 2
	# animation_finished is intentionally NOT connected — we drive state transitions
	# from _physics_process via _anim_ticks_remaining to stay deterministic.
	if face_left:
		anim.flip_h = true
	if health_bar_path:
		_health_bar = get_node(health_bar_path)
		_health_bar.max_value = max_health
		_health_bar.value = health
	_action_bits = {
		action_left: 1,
		action_right: 2,
		action_jump: 4,
		action_down: 8,
		action_punch: 16,
		action_kick: 32,
	}


func apply_character(def: CharacterDef) -> void:
	display_name = def.display_name
	anim.frames = def.sprite_frames
	anim.modulate = def.modulate
	_punch_arm_extension = def.punch_arm_extension
	speed = def.speed
	jump_velocity = def.jump_velocity
	punch_damage = def.punch_damage
	kick_damage = def.kick_damage
	block_damage_modifier = def.block_damage_modifier
	max_health = def.max_health
	health = max_health
	if _health_bar:
		_health_bar.max_value = max_health
	launch_punch = def.launch_punch
	combos_enabled = def.combos_enabled
	body_punch_enabled = def.body_punch_enabled
	kick_speed_scale = def.kick_speed_scale
	_lunge_upwards_kick = def.lunge_upwards_kick
	punch_speed_scale = def.punch_speed_scale
	flykick_speed_scale = def.flykick_speed_scale
	flypunch_speed_scale = def.flypunch_speed_scale
	kick_lunge_scale = def.kick_lunge_scale
	punch_lunge_scale = def.punch_lunge_scale
	kick_heals_self = def.kick_heals_self
	kick_knockback_multiplier = def.kick_knockback_multiplier
	fires_projectile = def.fires_projectile
	_proj_fires_on_punch = def.proj_fires_on_punch
	_proj_fires_on_kick = def.proj_fires_on_kick
	_proj_texture_punch = def.proj_texture
	_proj_texture_kick_tex = def.proj_texture_kick
	_proj_scale_base = def.proj_scale
	_proj_scale_kick = def.proj_scale_kick
	_proj_anim_hframes_kick = def.proj_anim_hframes_kick
	_proj_anim_vframes_kick = def.proj_anim_vframes_kick
	_proj_anim_fps_kick = def.proj_anim_fps_kick
	_proj_speed = def.proj_speed
	_proj_damage = def.proj_damage
	_proj_hit_radius = def.proj_hit_radius
	_proj_y_tolerance = def.proj_y_tolerance
	_proj_kick_upwards = def.proj_kick_upwards
	_proj_lifetime_ticks = def.proj_lifetime_ticks
	_proj_spawn_x_offset = def.proj_spawn_x_offset
	_proj_spawn_y_offset = def.proj_spawn_y_offset
	_proj_anim_hframes = def.proj_anim_hframes
	_proj_anim_vframes = def.proj_anim_vframes
	_proj_anim_fps = def.proj_anim_fps
	for s in _proj_sprites:
		s.queue_free()
	_proj_sprites.clear()
	_proj_active.clear()
	_proj_x.clear()
	_proj_y.clear()
	_proj_vy.clear()
	_proj_dir.clear()
	_proj_lifetime.clear()
	_proj_is_kick.clear()
	_proj_next = 0
	_proj_pool = def.proj_pool
	for i in range(_proj_pool):
		_proj_active.append(false)
		_proj_x.append(0)
		_proj_y.append(0)
		_proj_vy.append(0)
		_proj_dir.append(1)
		_proj_lifetime.append(0)
		_proj_is_kick.append(false)
		var s := Sprite.new()
		s.set_as_toplevel(true)
		s.scale = Vector2(def.proj_scale, def.proj_scale)  # overridden per-type at launch
		s.visible = false
		add_child(s)
		_proj_sprites.append(s)
	fall_gravity_scale = def.fall_gravity_scale
	invulnerable_when_airborne = def.invulnerable_when_airborne
	partial_loop_jump = def.partial_loop_jump
	punch_pulls_opponent = def.punch_pulls_opponent
	punch_makes_invisible = def.punch_makes_invisible
	proj_fires_airborne = def.proj_fires_airborne
	whataboutism_blocks = def.whataboutism_blocks
	anim.scale = Vector2(3.0, 3.0) * def.sprite_scale
	anim.offset = Vector2(0, -64) + def.sprite_offset
	anim.play("idle")


func reset_for_round() -> void:
	health = max_health
	is_defeated = false
	state = State.NORMAL
	hit_count = 0
	_hit_ticks = 0
	_attacking = false
	velocity = Vector2.ZERO
	_knockback_x = 0
	_hitstop_ticks = 0
	_block_stun_ticks = 0
	_current_anim = ""
	stay_down = false
	input_disabled = false
	_input_buffer.clear()
	_input_buffer_ticks = 0
	_current_combo_count = 0
	_pending_special = false
	_blocked_punch = false
	_proj_next = 0
	for i in range(_proj_pool):
		_proj_active[i] = false
		_proj_lifetime[i] = 0
		_proj_is_kick[i] = false
		_proj_sprites[i].visible = false
	_committed_keys = 0
	_prev_committed_keys = 0
	_invis_ticks = 0
	anim.modulate.a = 1.0
	_anim_hit_fired = false
	_attack_hit_tick = -1
	_attack_tick_count = 0
	_attack_is_kick = false
	_anim_ticks_remaining = -1
	_proj_launch_fired = false
	_proj_launch_tick = -1
	_proj_launch_count = 0
	global_position = _start_position
	if _health_bar:
		_health_bar.value = health
	_play_anim("idle")


func _play_anim(anim_name: String) -> void:
	if _current_anim != anim_name:
		_current_anim = anim_name
		_anim_hit_fired = false
		_attack_tick_count = 0
		_attack_hit_tick = -1
		_attack_is_kick = false
		_anim_ticks_remaining = -1
		_proj_launch_fired = false
		_proj_launch_tick = -1
		_proj_launch_count = 0

		var speed_scale: float
		if anim_name == "kick":
			speed_scale = kick_speed_scale
		elif anim_name == "flykick":
			speed_scale = flykick_speed_scale
		elif anim_name == "punch" or anim_name == "body_punch":
			if proj_fires_airborne and not is_on_floor():
				speed_scale = flypunch_speed_scale
			else:
				speed_scale = punch_speed_scale
		elif anim_name == "flypunch":
			speed_scale = flypunch_speed_scale
		else:
			speed_scale = 1.0
		anim.speed_scale = speed_scale

		if anim.frames and anim.frames.has_animation(anim_name):
			var fps_raw := anim.frames.get_animation_speed(anim_name) * speed_scale
			var fps_int := max(1, int(round(fps_raw)))
			var phz     := Engine.iterations_per_second

			# Hit-frame tick for attack animations (integer ceiling: no float ops).
			var target_frame := -1
			if anim_name == "punch" or anim_name == "flypunch":
				target_frame = 1
			elif anim_name == "bodypunch":
				target_frame = 2
			elif anim_name == "kick" or anim_name == "flykick":
				target_frame = 2
				_attack_is_kick = true
			if target_frame >= 0:
				_attack_hit_tick = (target_frame * phz + fps_int - 1) / fps_int

			var _fires_this_anim := (fires_projectile and (
				(_proj_fires_on_punch and anim_name == "punch") or
				(_proj_fires_on_kick and anim_name == "kick")
			))
			if _fires_this_anim:
				_proj_pending_is_kick = (anim_name == "kick")
				var proj_frame := 3 if anim_name == "punch" else 2
				_proj_launch_tick = (proj_frame * phz + fps_int - 1) / fps_int

			# Animation-end tick for non-looping animations.
			if not anim.frames.get_animation_loop(anim_name):
				var fc := anim.frames.get_frame_count(anim_name)
				_anim_ticks_remaining = (fc * phz + fps_int - 1) / fps_int

		anim.play(anim_name)


func _find_opponent() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p != self:
			_opponent = p as KinematicBody2D
			return


func _set_frozen(value: bool) -> void:
	frozen = value
	if anim:
		anim.playing = not value


func _move_with_floor_snap() -> Vector2:
	var snap := Vector2.ZERO
	if velocity.y >= 0.0:
		snap = FLOOR_SNAP
	return move_and_slide_with_snap(velocity + Vector2(_knockback_x, 0), snap, Vector2.UP)


func _separate_from_opponent() -> void:
	if _opponent == null:
		return
	for i in range(get_slide_count()):
		var col = get_slide_collision(i)
		if col.collider == _opponent:
			if col.normal.y < -0.5:
				var push_dir = sign(global_position.x - _opponent.global_position.x)
				if push_dir == 0:
					push_dir = -1.0 if face_left else 1.0
				velocity.x = push_dir * speed
				global_position.x += push_dir * 6.0


# Called from _physics_process when _anim_ticks_remaining hits zero.
# Replaces the render-loop animation_finished signal for deterministic state transitions.
func _handle_animation_finished() -> void:
	match state:
		State.HIT:
			state = State.NORMAL
		State.FALLEN:
			if not is_on_floor():
				# Still airborne — loop the falls animation until landing.
				_current_anim = ""
				_play_anim("falls")
				return
			if stay_down:
				anim.frame = anim.frames.get_frame_count("falls") - 1
				anim.stop()
				return
			if is_defeated:
				pass  # stay on last frame
			else:
				state = State.GETUP
				_play_anim("getup")
		State.GETUP:
			state = State.NORMAL
			hit_count = 0
			if _opponent:
				_opponent._current_combo_count = 0
		_:
			if _attacking:
				_attacking = false
				if state == State.NORMAL:
					_play_anim("idle")


func force_getup() -> void:
	state = State.GETUP
	_play_anim("getup")


func force_punch() -> void:
	if _opponent == null: _find_opponent()
	_attacking = true
	_play_anim("punch")


func force_fall() -> void:
	_enter_fallen()


func take_hit(is_kick: bool, attacker_pos: Vector2, is_counter: bool = false, damage: int = 15, knockback_multiplier: float = 1.0) -> bool:
	_end_invisibility()
	if is_defeated or state == State.GETUP:
		return false
	if state == State.FALLEN and is_on_floor():
		return false
	if invulnerable_when_airborne and not is_on_floor():
		return false

	var to_opp_block := 0.0
	if _opponent:
		to_opp_block = _opponent.global_position.x - global_position.x
	var is_blocking = _check_blocking(to_opp_block)
	if is_counter: damage = int(damage * COUNTER_HIT_BONUS)

	var block_broken := false

	if is_blocking:
		if is_kick:
			block_broken = true
			_apply_impact(attacker_pos, knockback_multiplier)
		else:
			damage = int(damage * block_damage_modifier)
			_apply_impact(attacker_pos, 0.5)
			state = State.BLOCKING
			_block_stun_ticks = BLOCK_STUN_TICKS
			_blocked_punch = true
			_play_anim("block")
			if anim.frame >= 1:
				anim.frame = 1
				anim.stop()
			if _opponent:
				_opponent._current_combo_count = 0
			if whataboutism_blocks:
				_whataboutism_window_ticks = COMBO_INPUT_WINDOW_TICKS
				_whataboutism_block_count += 1
				if _whataboutism_block_count >= 3:
					_whataboutism_block_count = 0
					_whataboutism_window_ticks = 0
					emit_signal("whataboutism_triggered")
					if _opponent:
						_opponent._pending_whataboutism = true
						_opponent._pending_whataboutism_pos = global_position
						_opponent._pending_whataboutism_damage = kick_damage
						_opponent._pending_whataboutism_knockback = kick_knockback_multiplier
	else:
		_apply_impact(attacker_pos, knockback_multiplier if is_kick else 1.0)
		hit_count += 1
		_hit_ticks = HIT_WINDOW_TICKS
		_current_combo_count = 0

	health = max(0, health - damage)
	if _health_bar:
		_health_bar.value = health

	if health <= 0:
		_enter_defeated()
		return true

	if not is_blocking or block_broken:
		if state == State.FALLEN:
			anim.stop()
			anim.frame = 2
			velocity.y = -500.0
		elif block_broken or not is_on_floor() or hit_count >= HIT_COMBO_THRESHOLD:
			var launch = is_on_floor() and hit_count >= HIT_COMBO_THRESHOLD and not block_broken
			hit_count = 0
			_hit_ticks = 0
			_enter_fallen()
			if launch:
				velocity.y = -900.0
		else:
			_enter_hit()

	_hitstop_ticks = HITSTOP_TICKS
	return true


func _check_blocking(to_opp: float) -> bool:
	var input_left  = _action_pressed(action_left)
	var input_right = _action_pressed(action_right)

	if to_opp > 0 and input_left:  return true
	if to_opp < 0 and input_right: return true
	return false


func _apply_impact(attacker_pos: Vector2, multiplier: float) -> void:
	var dir = (global_position.x - attacker_pos.x)
	if dir == 0: dir = -1.0 if anim.flip_h else 1.0
	dir = sign(dir)
	_knockback_x = int(dir * KNOCKBACK_FORCE * multiplier)


func _apply_pull(attacker_pos: Vector2) -> void:
	if is_defeated or state == State.GETUP:
		return
	if invulnerable_when_airborne and not is_on_floor():
		return
	var dir = sign(attacker_pos.x - global_position.x)
	_knockback_x = int(dir * KNOCKBACK_FORCE)
	_hitstop_ticks = HITSTOP_TICKS
	_enter_hit()


func _enter_hit() -> void:
	state = State.HIT
	_attacking = false
	velocity.x = 0.0
	_play_anim("gets_hit")


func _enter_fallen() -> void:
	state = State.FALLEN
	_attacking = false
	velocity = Vector2.ZERO
	_play_anim("falls")


func _enter_launched(attacker_pos: Vector2) -> void:
	state = State.FALLEN
	_attacking = false
	_block_stun_ticks = 0
	_blocked_punch = false
	_apply_impact(attacker_pos, 3)
	velocity.y = -1100.0
	_current_anim = ""
	_play_anim("jump")


func _enter_defeated() -> void:
	is_defeated = true
	state = State.FALLEN
	_attacking = false
	velocity = Vector2.ZERO
	_play_anim("falls")
	emit_signal("defeated")


func _end_invisibility() -> void:
	if _invis_ticks > 0:
		_invis_ticks = 0
		anim.modulate.a = 1.0


func _try_hit_opponent(is_kick: bool) -> void:
	if is_kick and kick_heals_self > 0:
		health = min(max_health, health + kick_heals_self)
		if _health_bar:
			_health_bar.value = health
		return

	if _opponent == null:
		_find_opponent()
	if _opponent == null:
		return

	var y_diff = abs(global_position.y - _opponent.global_position.y)
	var y_threshold = 330 if (_opponent.state == State.FALLEN and not _opponent.is_on_floor()) else 120
	if y_diff > y_threshold: return

	var facing_dir  := -1.0 if anim.flip_h else 1.0
	var to_opponent := _opponent.global_position.x - global_position.x

	if sign(to_opponent) != sign(facing_dir):
		return

	if punch_pulls_opponent and not is_kick:
		if abs(to_opponent) > PULL_RANGE:
			return
		_opponent._apply_pull(global_position)
		_hitstop_ticks = HITSTOP_TICKS
		emit_signal("hit_landed", false, 0)
		return

	var extension   := KICK_LEG_EXTENSION if is_kick else _punch_arm_extension
	var hit_x       := global_position.x + facing_dir * extension
	var fist_to_opp := abs(hit_x - _opponent.global_position.x)
	if fist_to_opp > HIT_TARGET_RADIUS:
		return

	var is_counter  = _opponent._attacking

	var hit_registered = _opponent.take_hit(is_kick, global_position, is_counter, kick_damage if is_kick else punch_damage, kick_knockback_multiplier if is_kick else 1.0)
	if not hit_registered:
		return
	_hitstop_ticks = HITSTOP_TICKS
	if punch_makes_invisible and not is_kick:
		_invis_ticks = INVIS_MAX_TICKS
		anim.modulate.a = 0.0

	if launch_punch and not is_kick and not _opponent.is_defeated:
		_opponent._enter_launched(global_position)

	if _pending_special:
		_pending_special = false
		var bonus = SPECIAL_COMBO_DAMAGE - (kick_damage if is_kick else punch_damage)
		_opponent.health = max(0, _opponent.health - bonus)
		if _opponent._health_bar:
			_opponent._health_bar.value = _opponent.health
		if _opponent.health <= 0 and not _opponent.is_defeated:
			_opponent._enter_defeated()

	if combos_enabled:
		_current_combo_count += 1
	var show_combo = combos_enabled and (_opponent.state == State.FALLEN)
	emit_signal("hit_landed", is_kick, _current_combo_count if show_combo else 0)


func _record_input(input_type: String) -> void:
	_input_buffer_ticks = COMBO_INPUT_WINDOW_TICKS
	_input_buffer.append(input_type)
	var seq_len = SPECIAL_COMBO_SEQUENCE.size()
	if _input_buffer.size() > seq_len:
		_input_buffer = _input_buffer.slice(_input_buffer.size() - seq_len, _input_buffer.size() - 1)
	_check_special_combo()


func _check_special_combo() -> void:
	if _input_buffer.size() < SPECIAL_COMBO_SEQUENCE.size():
		return
	for i in range(SPECIAL_COMBO_SEQUENCE.size()):
		if _input_buffer[i] != SPECIAL_COMBO_SEQUENCE[i]:
			return
	_input_buffer.clear()
	_input_buffer_ticks = 0
	_pending_special = true
	emit_signal("special_combo_triggered")


func _launch_projectile() -> void:
	var facing_dir := -1 if anim.flip_h else 1
	var i := _proj_next
	_proj_next = (_proj_next + 1) % _proj_pool
	_proj_active[i] = true
	_proj_is_kick[i] = _proj_pending_is_kick
	_proj_dir[i] = facing_dir
	_proj_x[i] = int(global_position.x) + facing_dir * _proj_spawn_x_offset
	_proj_y[i] = int(global_position.y) - _proj_spawn_y_offset
	_proj_vy[i] = -_proj_speed if _proj_kick_upwards and _proj_pending_is_kick else 0
	_proj_lifetime[i] = 0
	var s: Sprite = _proj_sprites[i]
	if _proj_pending_is_kick and _proj_texture_kick_tex:
		s.texture = _proj_texture_kick_tex
		s.hframes = _proj_anim_hframes_kick
		s.vframes = _proj_anim_vframes_kick
		var sk := _proj_scale_kick if _proj_scale_kick > 0.0 else _proj_scale_base
		s.scale = Vector2(sk, sk)
	else:
		s.texture = _proj_texture_punch
		s.hframes = _proj_anim_hframes
		s.vframes = _proj_anim_vframes
		s.scale = Vector2(_proj_scale_base, _proj_scale_base)


func _update_projectile() -> void:
	if _opponent == null:
		_find_opponent()
	for i in range(_proj_pool):
		if not _proj_active[i]:
			continue
		_proj_x[i] += _proj_dir[i] * _proj_speed
		_proj_y[i] += _proj_vy[i]
		_proj_lifetime[i] += 1

		if _proj_lifetime[i] > _proj_lifetime_ticks or _proj_x[i] < -200 or _proj_x[i] > 1500:
			_proj_active[i] = false
			continue

		if _opponent == null:
			continue

		var dx := abs(_proj_x[i] - int(_opponent.global_position.x))
		var dy := abs(_proj_y[i] - int(_opponent.global_position.y))
		if dx < _proj_hit_radius and dy < _proj_y_tolerance and int(_opponent.global_position.y) >= _proj_y[i]:
			_proj_active[i] = false
			var hit_pos := Vector2(_proj_x[i], _proj_y[i])
			var registered: bool = _opponent.take_hit(false, hit_pos, false, _proj_damage)
			if registered:
				_hitstop_ticks = HITSTOP_TICKS
				emit_signal("hit_landed", false, 0)


func set_committed_keys(keys: int) -> void:
	_committed_keys = keys


func _get_bit(keys: int, bit: int) -> bool:
	return bool(keys & bit)


func _action_pressed(action: String) -> bool:
	if is_networked:
		return bool(_committed_keys & int(_action_bits.get(action, 0)))
	if input_disabled:
		return false
	return Input.is_action_pressed(action)


func _action_just_pressed(action: String) -> bool:
	if is_networked:
		var bit := int(_action_bits.get(action, 0))
		return bool(_committed_keys & bit) and not bool(_prev_committed_keys & bit)
	if input_disabled:
		return false
	return Input.is_action_just_pressed(action)


func _physics_process(delta: float) -> void:
	if frozen:
		return
	var is_on_floor_t = is_on_floor()
	if _pending_whataboutism:
		_pending_whataboutism = false
		_end_invisibility()
		if not is_defeated and not (state == State.FALLEN and is_on_floor_t):
			_apply_impact(_pending_whataboutism_pos, _pending_whataboutism_knockback)
			health = max(0, health - _pending_whataboutism_damage)
			if _health_bar:
				_health_bar.value = health
			if health <= 0:
				_enter_defeated()
			else:
				_enter_fallen()
			_hitstop_ticks = HITSTOP_TICKS
		return
	if _opponent == null:
		_find_opponent()

	# Cache all inputs once to avoid repeated is_networked checks and dict lookups.
	var inp_left:     bool = _action_pressed(action_left)
	var inp_right:    bool = _action_pressed(action_right)
	var inp_down:     bool = _action_pressed(action_down)
	var inp_jump_jp:  bool = _action_just_pressed(action_jump)
	var inp_punch_jp: bool = _action_just_pressed(action_punch)
	var inp_kick_jp:  bool = _action_just_pressed(action_kick)

	var cur_state = state

	var to_opp := 0.0
	var is_blocking_input := false
	if _opponent:
		to_opp = _opponent.global_position.x - global_position.x
		if   to_opp > 0 and inp_left:  is_blocking_input = true
		elif to_opp < 0 and inp_right: is_blocking_input = true

	if cur_state == State.BLOCKING and _blocked_punch and (not input_disabled or is_networked):
		if inp_jump_jp and is_on_floor_t:
			_block_stun_ticks = 0
			_blocked_punch = false
			state = State.NORMAL
			cur_state = State.NORMAL
			velocity.y = jump_velocity

	if cur_state == State.NORMAL and _hitstop_ticks == 0 and (not input_disabled or is_networked):
		if not _attacking and not is_blocking_input:
			if inp_punch_jp:
				_attacking = true
				if not is_on_floor_t:
					if proj_fires_airborne:
						_play_anim("punch")
					else:
						_play_anim("flypunch")
				elif body_punch_enabled:
					_play_anim("bodypunch")
				else:
					_play_anim("punch")
				if combos_enabled:
					_record_input("punch")
			elif inp_kick_jp:
				_attacking = true
				_play_anim("flykick" if not is_on_floor_t else "kick")
				if combos_enabled:
					_record_input("kick")
		if inp_jump_jp and is_on_floor_t and not _attacking:
			velocity.y = jump_velocity

	if _input_buffer_ticks > 0:
		_input_buffer_ticks -= 1
		if _input_buffer_ticks == 0:
			_input_buffer.clear()

	# Advance animation-end counter before hitstop so it keeps pace with the
	# visual animation (AnimatedSprite runs in the render loop regardless of hitstop).
	if _anim_ticks_remaining > 0:
		_anim_ticks_remaining -= 1
		if _anim_ticks_remaining == 0:
			_handle_animation_finished()
			cur_state = state  # refresh after possible state change

	if _hitstop_ticks > 0:
		_hitstop_ticks -= 1
		return  # freeze all movement

	# Physics-deterministic hit detection: same exec_frame on both clients.
	if _attacking and not _anim_hit_fired and _attack_hit_tick >= 0:
		_attack_tick_count += 1
		if _attack_tick_count >= _attack_hit_tick:
			_anim_hit_fired = true
			_try_hit_opponent(_attack_is_kick)

	if _attacking and not _proj_launch_fired and _proj_launch_tick >= 0:
		_proj_launch_count += 1
		if _proj_launch_count >= _proj_launch_tick:
			_proj_launch_fired = true
			_launch_projectile()

	if fires_projectile:
		_update_projectile()
		for i in range(_proj_pool):
			var s: Sprite = _proj_sprites[i]
			s.visible = _proj_active[i]
			if _proj_active[i]:
				s.global_position = Vector2(_proj_x[i], _proj_y[i])
				s.flip_h = (_proj_dir[i] < 0)
				var hf := _proj_anim_hframes_kick if _proj_is_kick[i] else _proj_anim_hframes
				var vf := _proj_anim_vframes_kick if _proj_is_kick[i] else _proj_anim_vframes
				var fps := _proj_anim_fps_kick if _proj_is_kick[i] else _proj_anim_fps
				if hf * vf > 1:
					s.frame = (_proj_lifetime[i] * fps / Engine.iterations_per_second) % (hf * vf)

	if _hit_ticks > 0:
		_hit_ticks -= 1
		if _hit_ticks == 0:
			hit_count = 0
			if _opponent:
				_opponent._current_combo_count = 0

	if _invis_ticks > 0:
		_invis_ticks -= 1
		if _invis_ticks == 0:
			anim.modulate.a = 1.0

	# Integer multiply-divide: no float FMA non-determinism across platforms.
	_knockback_x = _knockback_x * 5 / 6

	if _block_stun_ticks > 0:
		_block_stun_ticks -= 1
		if _block_stun_ticks == 0:
			state = State.NORMAL
			cur_state = State.NORMAL
			_blocked_punch = false

	if _whataboutism_window_ticks > 0:
		_whataboutism_window_ticks -= 1
		if _whataboutism_window_ticks == 0:
			_whataboutism_block_count = 0

	if not is_on_floor_t:
		# Round gravity accumulation to prevent float drift between clients.
		var grav_scale := fall_gravity_scale if cur_state == State.NORMAL else 1.0
		velocity.y = round(velocity.y + GRAVITY * (3.0 if inp_down else 1.0) * grav_scale * delta)

	# Launched players play looping "jump"; switch to non-looping "falls" once descending.
	if cur_state == State.FALLEN and _current_anim == "jump" and velocity.y >= 0:
		_current_anim = ""
		_play_anim("falls")

	if cur_state == State.FALLEN or cur_state == State.GETUP or cur_state == State.BLOCKING:
		velocity.x = 0.0
		velocity = _move_with_floor_snap()
		global_position.x = round(global_position.x)
		global_position.y = round(global_position.y)
		return

	var direction := float(inp_right) - float(inp_left)

	var is_opponent_attacking = _opponent._attacking
	var is_walking_back = false

	var dist_to_opp = abs(to_opp)
	if (to_opp > 0 and direction < 0) or (to_opp < 0 and direction > 0):
		is_walking_back = true

	var should_block_visually = is_blocking_input and is_opponent_attacking and dist_to_opp < PROXIMITY_BLOCK_RANGE

	if cur_state == State.HIT and should_block_visually and is_on_floor_t:
		velocity.x = 0.0
	elif _attacking and (is_on_floor_t or (_lunge_upwards_kick and _attack_is_kick)) and not fires_projectile:
		var lunge = 1.0 if not anim.flip_h else -1.0
		var lunge_scale = kick_lunge_scale if _attack_is_kick else punch_lunge_scale
		velocity.x = lunge * (speed * 0.3 * lunge_scale)
		if _lunge_upwards_kick and _attack_is_kick and is_on_floor_t:
			velocity.y = -(speed * 0.7 * lunge_scale)
	else:
		var current_speed = speed
		if is_walking_back:
			current_speed = speed * WALK_BACK_SPEED_MULT
		if velocity.y != 0:
			current_speed = speed * 2
		velocity.x = direction * current_speed

	velocity = _move_with_floor_snap()

	global_position.x = round(global_position.x)
	global_position.y = round(global_position.y)

	# Animation updates
	if cur_state == State.NORMAL and not _attacking:
		if should_block_visually and is_on_floor_t:
			_play_anim("block")
			if anim.frame >= 1:
				anim.frame = 1
				anim.stop()
		elif not is_on_floor_t:
			_play_anim("jump")
			if partial_loop_jump and anim.frame >= 2:
				anim.stop()
				anim.frame = 2
		elif direction != 0:
			_play_anim("walk")
		else:
			_play_anim("idle")

	if cur_state == State.BLOCKING and _current_anim != "block":
		_play_anim("block")
		if anim.frame >= 1:
			anim.frame = 1
			anim.stop()

	# Auto-face opponent when idle, walking, or blocking
	if not _attacking and is_on_floor_t and (cur_state == State.NORMAL or cur_state == State.BLOCKING):
		if _opponent:
			if dist_to_opp > 50:
				anim.flip_h = to_opp < 0

	_prev_committed_keys = _committed_keys

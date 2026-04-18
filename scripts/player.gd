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
const KNOCKBACK_FORCE      := 500.0
var block_damage_modifier := 0.15
const HITSTOP_TICKS        := 6    # 0.1 s at 60 Hz
const COUNTER_HIT_BONUS    := 1.5
const PROXIMITY_BLOCK_RANGE := 500.0
const BLOCK_STUN_TICKS     := 12   # 0.2 s at 60 Hz
const WALK_BACK_SPEED_MULT := 0.65
const COMBO_INPUT_WINDOW_TICKS := 30  # 0.5 s at 60 Hz
const SPECIAL_COMBO_DAMAGE := 35
const SPECIAL_COMBO_SEQUENCE := ["punch", "punch", "kick"]

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
var stay_down: bool = false
var input_disabled: bool = false
var _input_buffer: Array = []
var _input_buffer_ticks: int = 0
var _current_combo_count: int = 0
var _pending_special: bool = false

# Networked input — set by fight.gd each frame in online mode.
var is_networked: bool = false
var _committed_keys: int = 0
var _prev_committed_keys: int = 0

# Physics-tick hit detection: fires after a fixed tick count from animation FPS.
# Both clients compute the same integer and start from the same exec_frame.
var _anim_hit_fired: bool = false
var _attack_hit_tick: int = -1
var _attack_tick_count: int = 0
var _attack_is_kick: bool = false

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
	_opponent = null
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
	_committed_keys = 0
	_prev_committed_keys = 0
	_anim_hit_fired = false
	_attack_hit_tick = -1
	_attack_tick_count = 0
	_attack_is_kick = false
	_anim_ticks_remaining = -1
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

		var speed_scale := kick_speed_scale if anim_name in ["kick", "flykick"] else 1.0
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


func take_hit(is_kick: bool, attacker_pos: Vector2, is_counter: bool = false, damage: int = 15) -> bool:
	if is_defeated or state == State.GETUP:
		return false
	if state == State.FALLEN and is_on_floor():
		return false

	var is_blocking = _check_blocking()
	if is_counter: damage = int(damage * COUNTER_HIT_BONUS)

	var block_broken := false

	if is_blocking:
		if is_kick:
			block_broken = true
			_apply_impact(attacker_pos, 1.0)
		else:
			damage = int(damage * block_damage_modifier)
			_apply_impact(attacker_pos, 0.5)
			state = State.BLOCKING
			_block_stun_ticks = BLOCK_STUN_TICKS
			_blocked_punch = true
			if _opponent:
				_opponent._current_combo_count = 0
	else:
		_apply_impact(attacker_pos, 1.0)
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


func _check_blocking() -> bool:
	if _opponent == null: _find_opponent()
	if _opponent == null: return false

	var to_opp    = _opponent.global_position.x - global_position.x
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
	_apply_impact(attacker_pos, 1.5)
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


func _try_hit_opponent(is_kick: bool) -> void:
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

	var extension   := KICK_LEG_EXTENSION if is_kick else _punch_arm_extension
	var hit_x       := global_position.x + facing_dir * extension
	var fist_to_opp := abs(hit_x - _opponent.global_position.x)
	if fist_to_opp > HIT_TARGET_RADIUS:
		return

	var is_counter  = _opponent._attacking

	var hit_registered = _opponent.take_hit(is_kick, global_position, is_counter, kick_damage if is_kick else punch_damage)
	if not hit_registered:
		return
	_hitstop_ticks = HITSTOP_TICKS

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


func set_committed_keys(keys: int) -> void:
	_committed_keys = keys


func _get_bit(keys: int, bit: int) -> bool:
	return bool(keys & bit)


func _action_pressed(action: String) -> bool:
	if is_networked:
		if action == action_left:    return _get_bit(_committed_keys, 1)
		elif action == action_right: return _get_bit(_committed_keys, 2)
		elif action == action_jump:  return _get_bit(_committed_keys, 4)
		elif action == action_down:  return _get_bit(_committed_keys, 8)
		elif action == action_punch: return _get_bit(_committed_keys, 16)
		elif action == action_kick:  return _get_bit(_committed_keys, 32)
		return false
	if input_disabled:
		return false
	return Input.is_action_pressed(action)


func _action_just_pressed(action: String) -> bool:
	if is_networked:
		var cur  := false
		var prev := false
		if action == action_left:
			cur  = _get_bit(_committed_keys,      1)
			prev = _get_bit(_prev_committed_keys, 1)
		elif action == action_right:
			cur  = _get_bit(_committed_keys,      2)
			prev = _get_bit(_prev_committed_keys, 2)
		elif action == action_jump:
			cur  = _get_bit(_committed_keys,      4)
			prev = _get_bit(_prev_committed_keys, 4)
		elif action == action_down:
			cur  = _get_bit(_committed_keys,      8)
			prev = _get_bit(_prev_committed_keys, 8)
		elif action == action_punch:
			cur  = _get_bit(_committed_keys,      16)
			prev = _get_bit(_prev_committed_keys, 16)
		elif action == action_kick:
			cur  = _get_bit(_committed_keys,      32)
			prev = _get_bit(_prev_committed_keys, 32)
		return cur and not prev
	if input_disabled:
		return false
	return Input.is_action_just_pressed(action)


func _physics_process(delta: float) -> void:
	if frozen:
		return

	if state == State.BLOCKING and _blocked_punch and (not input_disabled or is_networked):
		if _action_just_pressed(action_jump) and is_on_floor():
			_block_stun_ticks = 0
			_blocked_punch = false
			state = State.NORMAL
			velocity.y = jump_velocity

	if state == State.NORMAL and _hitstop_ticks == 0 and (not input_disabled or is_networked):
		if not _attacking and not _check_blocking():
			if _action_just_pressed(action_punch):
				_attacking = true
				if not is_on_floor():
					_play_anim("flypunch")
				elif body_punch_enabled:
					_play_anim("bodypunch")
				else:
					_play_anim("punch")
				if combos_enabled:
					_record_input("punch")
			elif _action_just_pressed(action_kick):
				_attacking = true
				_play_anim("flykick" if not is_on_floor() else "kick")
				if combos_enabled:
					_record_input("kick")
		if _action_just_pressed(action_jump) and is_on_floor() and not _attacking:
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

	if _hitstop_ticks > 0:
		_hitstop_ticks -= 1
		return  # freeze all movement

	# Physics-deterministic hit detection: same exec_frame on both clients.
	if _attacking and not _anim_hit_fired and _attack_hit_tick >= 0:
		_attack_tick_count += 1
		if _attack_tick_count >= _attack_hit_tick:
			_anim_hit_fired = true
			_try_hit_opponent(_attack_is_kick)

	if _hit_ticks > 0:
		_hit_ticks -= 1
		if _hit_ticks == 0:
			hit_count = 0
			if _opponent:
				_opponent._current_combo_count = 0

	# Integer multiply-divide: no float FMA non-determinism across platforms.
	_knockback_x = _knockback_x * 5 / 6

	if _block_stun_ticks > 0:
		_block_stun_ticks -= 1
		if _block_stun_ticks == 0:
			state = State.NORMAL
			_blocked_punch = false

	if not is_on_floor():
		var fast_fall = _action_pressed(action_down)
		# Round gravity accumulation to prevent float drift between clients.
		velocity.y = round(velocity.y + GRAVITY * (3.0 if fast_fall else 1.0) * delta)

	# Launched players play looping "jump"; switch to non-looping "falls" once descending.
	if state == State.FALLEN and _current_anim == "jump" and velocity.y >= 0:
		_current_anim = ""
		_play_anim("falls")

	if state == State.FALLEN or state == State.GETUP or state == State.BLOCKING:
		velocity.x = 0.0
		velocity = _move_with_floor_snap()
		_separate_from_opponent()
		if is_on_floor():
			velocity.y = 0.0
		global_position.x = round(global_position.x)
		global_position.y = round(global_position.y)
		return

	var left      := _action_pressed(action_left)
	var right     := _action_pressed(action_right)
	var direction := float(right) - float(left)

	if _opponent == null: _find_opponent()
	var is_blocking_input     = _check_blocking()
	var is_opponent_attacking = _opponent != null and _opponent._attacking
	var dist_to_opp  = 0.0
	var is_walking_back = false
	if _opponent:
		var to_opp = _opponent.global_position.x - global_position.x
		dist_to_opp = abs(to_opp)
		if (to_opp > 0 and direction < 0) or (to_opp < 0 and direction > 0):
			is_walking_back = true

	var should_block_visually = is_blocking_input and is_opponent_attacking and dist_to_opp < PROXIMITY_BLOCK_RANGE

	if state == State.HIT:
		velocity.x = 0.0
	elif _attacking:
		if is_on_floor():
			var lunge = 1.0 if not anim.flip_h else -1.0
			velocity.x = lunge * (speed * 0.3)
	elif should_block_visually and is_on_floor():
		velocity.x = 0.0
	else:
		var current_speed = speed
		if is_walking_back:
			current_speed = speed * WALK_BACK_SPEED_MULT
		velocity.x = direction * current_speed

	velocity = _move_with_floor_snap()
	_separate_from_opponent()
	if is_on_floor():
		velocity.y = 0.0
	global_position.x = round(global_position.x)
	global_position.y = round(global_position.y)

	# Animation updates
	if state == State.NORMAL and not _attacking:
		if should_block_visually and is_on_floor():
			_play_anim("block")
			if anim.frame >= 1:
				anim.frame = 1
				anim.stop()
		elif not is_on_floor():
			_play_anim("jump")
		elif direction != 0:
			_play_anim("walk")
		else:
			_play_anim("idle")

	if state == State.BLOCKING:
		_play_anim("block")
		if anim.frame >= 1:
			anim.frame = 1
			anim.stop()

	# Auto-face opponent when idle, walking, or blocking
	if not _attacking and is_on_floor() and (state == State.NORMAL or state == State.BLOCKING):
		if _opponent == null: _find_opponent()
		if _opponent:
			var to_opp = _opponent.global_position.x - global_position.x
			if abs(to_opp) > 50:
				anim.flip_h = to_opp < 0

	_prev_committed_keys = _committed_keys

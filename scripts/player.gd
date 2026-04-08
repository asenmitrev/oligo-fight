extends KinematicBody2D

const CharacterDef = preload("res://scripts/character_def.gd")

# Tighter, snappier movement constants
var speed := 350.0
var jump_velocity := -1700.0
const GRAVITY := 4800.0
const FLOOR_SNAP := Vector2(0, 24)

var punch_damage := 15
var kick_damage := 8
const HIT_COMBO_THRESHOLD := 2
const HIT_WINDOW := 2.0
const PUNCH_ARM_EXTENSION := 120.0  # px from player center to fist at full extension
const KICK_LEG_EXTENSION := 150.0   # px from player center to foot at full extension
const HIT_TARGET_RADIUS := 85.0
# Gameplay Feel Constants
const KNOCKBACK_FORCE := 500.0
var block_damage_modifier := 0.15
const HITSTOP_DURATION := 0.1
const COUNTER_HIT_BONUS := 1.5
const PROXIMITY_BLOCK_RANGE := 500.0
const BLOCK_STUN_DURATION := 0.2
const WALK_BACK_SPEED_MULT := 0.65
const COMBO_INPUT_WINDOW := 0.5
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
var hit_timer := 0.0
var _attacking := false
var _opponent: KinematicBody2D
var _health_bar: ProgressBar
var frozen: bool = false
var _punch_arm_extension: float = PUNCH_ARM_EXTENSION
var _start_position: Vector2
var velocity: Vector2 = Vector2.ZERO
var _hitstop_timer := 0.0
var _knockback_velocity := Vector2.ZERO
var _block_stun_timer := 0.0
var _blocked_punch: bool = false
var _current_anim: String = ""
var launch_punch: bool = false
var combos_enabled: bool = true
var stay_down: bool = false
var input_disabled: bool = false
var _input_buffer: Array = []
var _input_buffer_timer: float = 0.0
var _current_combo_count: int = 0
var _pending_special: bool = false

func _ready() -> void:
	_start_position = global_position
	add_to_group("players")
	# Ensure players collide with each other (Layer 2)
	collision_mask |= 2
	anim.connect("animation_finished", self, "_on_animation_finished")
	anim.connect("frame_changed", self, "_on_frame_changed")
	if face_left:
		anim.flip_h = true
	if health_bar_path:
		_health_bar = get_node(health_bar_path)
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
	launch_punch = def.launch_punch
	combos_enabled = def.combos_enabled
	anim.scale = Vector2(3.0, 3.0) * def.sprite_scale
	anim.offset = Vector2(0, -64) + def.sprite_offset
	anim.play("idle")

func reset_for_round() -> void:
	health = max_health
	is_defeated = false
	state = State.NORMAL
	hit_count = 0
	hit_timer = 0.0
	_attacking = false
	_opponent = null
	velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	_hitstop_timer = 0.0
	_block_stun_timer = 0.0
	_current_anim = ""
	stay_down = false
	input_disabled = false
	_input_buffer.clear()
	_input_buffer_timer = 0.0
	_current_combo_count = 0
	_pending_special = false
	_blocked_punch = false
	global_position = _start_position
	if _health_bar:
		_health_bar.value = health
	_play_anim("idle")

func _play_anim(anim_name: String) -> void:
	if _current_anim != anim_name:
		_current_anim = anim_name
		anim.play(anim_name)

func _find_opponent() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p != self:
			_opponent = p as KinematicBody2D
			return

func _move_with_floor_snap() -> Vector2:
	var snap := Vector2.ZERO
	if velocity.y >= 0.0:
		snap = FLOOR_SNAP
	# move_and_slide handles player-to-player pushing automatically if collision mask is set
	return move_and_slide_with_snap(velocity + _knockback_velocity, snap, Vector2.UP)

func _separate_from_opponent() -> void:
	if _opponent == null:
		return
	for i in range(get_slide_count()):
		var col = get_slide_collision(i)
		if col.collider == _opponent:
			# normal.y < -0.5 means opponent surface is below us — we're riding on top
			if col.normal.y < -0.5:
				var push_dir = sign(global_position.x - _opponent.global_position.x)
				if push_dir == 0:
					push_dir = -1.0 if face_left else 1.0
				velocity.x = push_dir * speed
				global_position.x += push_dir * 6.0

func _on_animation_finished() -> void:
	match state:
		State.HIT:
			state = State.NORMAL
		State.FALLEN:
			if stay_down:
				# Freeze on the last frame of the falls animation
				anim.frame = anim.frames.get_frame_count("falls") - 1
				anim.stop()
				return
			if is_defeated and not state == State.GETUP: # Added check to allow forced getup
				pass
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

func _on_frame_changed() -> void:
	if not _attacking: return
	
	var frame = anim.frame
	var anim_name = anim.animation
	
	if (anim_name == "punch" and frame == 1) or \
	   (anim_name == "flypunch" and frame == 1):
		_try_hit_opponent(false)
	elif (anim_name == "kick" and frame == 2) or \
	     (anim_name == "flykick" and frame == 2):
		_try_hit_opponent(true)

func take_hit(is_kick: bool, attacker_pos: Vector2, is_counter: bool = false) -> bool:
	if is_defeated or state == State.GETUP:
		return false
	if state == State.FALLEN and is_on_floor():
		return false

	# Blocking Logic
	var is_blocking = _check_blocking()
	var damage := kick_damage if is_kick else punch_damage
	if is_counter: damage *= COUNTER_HIT_BONUS

	var block_broken := false

	if is_blocking:
		if is_kick:
			# Kick breaks block — defender falls regardless
			block_broken = true
			_apply_impact(attacker_pos, 1.0)
		else:
			# Punch is blocked normally — jump can escape this stun
			damage = int(damage * block_damage_modifier)
			_apply_impact(attacker_pos, 0.5)
			state = State.BLOCKING
			_block_stun_timer = BLOCK_STUN_DURATION
			_blocked_punch = true
			if _opponent:
				_opponent._current_combo_count = 0
	else:
		_apply_impact(attacker_pos, 1.0)
		hit_count += 1
		hit_timer = HIT_WINDOW
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
			hit_timer = 0.0
			_enter_fallen()
			if launch:
				velocity.y = -900.0
		else:
			_enter_hit()

	# Trigger hitstop (freeze)
	_hitstop_timer = HITSTOP_DURATION
	return true

func _check_blocking() -> bool:
	if _opponent == null: _find_opponent()
	if _opponent == null: return false
	
	var to_opp = _opponent.global_position.x - global_position.x
	var input_left = Input.is_action_pressed(action_left)
	var input_right = Input.is_action_pressed(action_right)
	
	# Block by holding away from opponent
	if to_opp > 0 and input_left: return true
	if to_opp < 0 and input_right: return true
	return false

func _apply_impact(attacker_pos: Vector2, multiplier: float) -> void:
	var dir = (global_position.x - attacker_pos.x)
	if dir == 0: dir = -1.0 if anim.flip_h else 1.0
	dir = sign(dir)
	_knockback_velocity.x = dir * KNOCKBACK_FORCE * multiplier

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

	# Height check — more lenient when opponent is airborne (juggle window)
	var y_diff = abs(global_position.y - _opponent.global_position.y)
	var y_threshold = 330 if (_opponent.state == State.FALLEN and not _opponent.is_on_floor()) else 120
	if y_diff > y_threshold: return

	var facing_dir := -1.0 if anim.flip_h else 1.0
	var to_opponent := _opponent.global_position.x - global_position.x

	# Must be facing the opponent
	if sign(to_opponent) != sign(facing_dir):
		return

	# Project where the fist/foot actually is at full extension
	var extension := KICK_LEG_EXTENSION if is_kick else _punch_arm_extension
	var hit_x := global_position.x + facing_dir * extension

	# Hit registers when extended fist/foot overlaps the opponent's body
	var fist_to_opp := abs(hit_x - _opponent.global_position.x)
	if fist_to_opp > HIT_TARGET_RADIUS:
		return

	var is_counter = _opponent._attacking
	var hit_registered = _opponent.take_hit(is_kick, global_position, is_counter)
	if not hit_registered:
		return
	_hitstop_timer = HITSTOP_DURATION # Attacker also freezes

	# Boekov's launch punch: blast the opponent into the air with the jump animation
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
	_input_buffer_timer = COMBO_INPUT_WINDOW
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
	_input_buffer_timer = 0.0
	_pending_special = true
	emit_signal("special_combo_triggered")

func _physics_process(delta: float) -> void:
	if frozen:
		return

	# Poll attack/jump inputs each physics tick — more responsive than _unhandled_input
	# on slow hardware since it doesn't wait for event propagation through the scene tree
	if state == State.BLOCKING and _blocked_punch and not input_disabled:
		if Input.is_action_just_pressed(action_jump) and is_on_floor():
			# Jump escapes punch block stun
			_block_stun_timer = 0.0
			_blocked_punch = false
			state = State.NORMAL
			velocity.y = jump_velocity

	if state == State.NORMAL and _hitstop_timer <= 0 and not input_disabled:
		if not _attacking and not _check_blocking():
			if Input.is_action_just_pressed(action_punch):
				_attacking = true
				_play_anim("flypunch" if not is_on_floor() else "punch")
				if combos_enabled:
					_record_input("punch")
			elif Input.is_action_just_pressed(action_kick):
				_attacking = true
				_play_anim("flykick" if not is_on_floor() else "kick")
				if combos_enabled:
					_record_input("kick")
		if Input.is_action_just_pressed(action_jump) and is_on_floor() and not _attacking:
			velocity.y = jump_velocity

	if _input_buffer_timer > 0.0:
		_input_buffer_timer -= delta
		if _input_buffer_timer <= 0.0:
			_input_buffer.clear()

	if _hitstop_timer > 0:
		_hitstop_timer -= delta
		return # Freeze all movement and animation processing

	if state == State.FALLEN and not is_on_floor() and not anim.is_playing():
		_current_anim = ""
		_play_anim("falls")

	if hit_timer > 0.0:
		hit_timer -= delta
		if hit_timer <= 0.0:
			hit_count = 0
			if _opponent:
				_opponent._current_combo_count = 0

	# Friction for knockback
	_knockback_velocity.x = lerp(_knockback_velocity.x, 0, delta * 10.0)

	if _block_stun_timer > 0:
		_block_stun_timer -= delta
		if _block_stun_timer <= 0:
			state = State.NORMAL
			_blocked_punch = false

	if not is_on_floor():
		var fast_fall = not input_disabled and Input.is_action_pressed(action_down)
		velocity.y += GRAVITY * (3.0 if fast_fall else 1.0) * delta

	if state == State.FALLEN or state == State.GETUP or state == State.BLOCKING:
		velocity.x = 0.0
		velocity = _move_with_floor_snap()
		_separate_from_opponent()
		if is_on_floor():
			velocity.y = 0.0
		return

	var left := Input.is_action_pressed(action_left) if not input_disabled else false
	var right := Input.is_action_pressed(action_right) if not input_disabled else false
	var direction := float(right) - float(left)

	if _opponent == null: _find_opponent()
	var is_blocking_input = _check_blocking() if not input_disabled else false
	var is_opponent_attacking = _opponent != null and _opponent._attacking
	var dist_to_opp = 0.0
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
		# Small forward lunge when attacking on ground
		if is_on_floor():
			var lunge = 1.0 if not anim.flip_h else -1.0
			velocity.x = lunge * (speed * 0.3)
	elif should_block_visually and is_on_floor():
		# Stick in place like SF2 during proximity block
		velocity.x = 0.0
	else:
		# Slower back-walk for SF feel
		var current_speed = speed
		if is_walking_back:
			current_speed = speed * WALK_BACK_SPEED_MULT
		velocity.x = direction * current_speed

	velocity = _move_with_floor_snap()
	_separate_from_opponent()
	if is_on_floor():
		velocity.y = 0.0

	# Animation updates
	if state == State.NORMAL and not _attacking:
		if should_block_visually and is_on_floor():
			_play_anim("block")
			# Freeze on frame index 1 (the second frame) to hold the block pose
			if anim.frame >= 1:
				anim.frame = 1
				anim.stop()
		elif not is_on_floor():
			_play_anim("jump")
		elif direction != 0:
			_play_anim("walk")
		else:
			_play_anim("idle")

	# Block animation during stun
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

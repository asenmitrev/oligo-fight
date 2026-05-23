extends KinematicBody2D

const CharacterDef = preload("res://scripts/character_def.gd")

var speed := 350.0
var jump_speed := 350.0
var jump_velocity := -1700.0
const GRAVITY := 3600.0
const FLOOR_SNAP := Vector2(0, 24)

var punch_damage := 15
var kick_damage := 8
const HIT_COMBO_THRESHOLD := 5
const HIT_WINDOW_TICKS     := 120
const PUNCH_ARM_EXTENSION  := 120.0
const KICK_LEG_EXTENSION   := 150.0
const HIT_TARGET_RADIUS    := 85.0
const KNOCKBACK_FORCE      := 1500.0
const PULL_RANGE           := 350.0
var block_damage_modifier := 0.15
const HITSTOP_TICKS        := 6
const COUNTER_HIT_BONUS    := 1.5
const PROXIMITY_BLOCK_RANGE := 500.0
const BLOCK_STUN_TICKS     := 12
const WALK_BACK_SPEED_MULT := 0.65
const COMBO_INPUT_WINDOW_TICKS := 30

# Hit physics velocities
const HIT_BOUNCE_VELOCITY    := -500.0   # upward push when hit while already airborne
const LAUNCH_VELOCITY        := -900.0   # upward launch on combo knockdown
const STRONG_LAUNCH_VELOCITY := -1100.0  # stronger launch for launch_punch ability
const LAUNCH_KNOCKBACK_MULT  := 3.0      # knockback multiplier for launch_punch
const FAST_FALL_MULTIPLIER   := 3.0      # gravity scale when holding down mid-air
const KNOCKBACK_DECAY_FACTOR := 5.0 / 6.0  # per-tick friction on _knockback_x

# Movement fractions (relative to character speed)
const LUNGE_HORIZONTAL_FRACTION := 0.3
const LUNGE_VERTICAL_FRACTION   := 0.7
const FLYKICK_FORWARD_SPEED     := 2000.0

# Map bounds — used for teleport clamping
const MAP_LEFT_BOUND          := 10.0
const MAP_RIGHT_BOUND         := 1270.0
const MAP_TOP_BOUND           := 100.0
const MAP_BOTTOM_BOUND        := 460.0
const TELEPORT_SNAP_TOLERANCE := 5.0    # cancel teleport if target would clip a wall

# Teleport offsets
const KICK_TELEPORT_OFFSET     := 300.0  # distance behind attacker where opponent is placed
const FLYPUNCH_TELEPORT_OFFSET := 120.0  # distance behind opponent where self is placed

# Hit detection
const HIT_Y_THRESHOLD_AIRBORNE := 330.0  # max Y delta to connect with an airborne opponent
const HIT_Y_THRESHOLD_STANDING := 120.0  # max Y delta to connect with a standing opponent
const FLIP_DIRECTION_THRESHOLD := 50.0   # min dist to opponent before flipping sprite to face them
const PUNCH_SELF_DAMAGE        := 5      # HP cost per punch for punch_self_damages characters

# Projectile out-of-bounds and collision
const PROJ_OUT_BOUND_LEFT    := -200.0
const PROJ_OUT_BOUND_RIGHT   := 1500.0
const PROJ_GROUND_TOLERANCE  := 50.0    # Y margin for projectile ground-level collision

# Lottery projectile
const LOTTERY_DAMAGE_VALUES := [5, 10, 20, 30]

# Sprite defaults
const SPRITE_BASE_SCALE := 3.0    # pixel scale for AnimatedSprite (128px frame → 384px)
const SPRITE_Y_OFFSET   := -64.0  # anchor: half of 128px frame height

# IpMan passive attraction
const IPMAN_ATTRACTION_SPEED := 0.5  # pixels per physics tick

# Veli kick icon
const VELI_ICON_SCALE    := 1.2
const VELI_ICON_Y_OFFSET := -220.0
const VELI_ICON_X_SIDE   := 140.0

# Shared character config flags
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
var walk_self_heal: float = 0
var _has_healed_on_walk: bool = false
var kick_knockback_multiplier: float = 1.0
var punch_knockback_multiplier: float = 1.0
var fall_gravity_scale: float = 1.0
var invulnerable_when_airborne: bool = false
var partial_loop_jump: bool = false
var punch_pulls_opponent: bool = false
var punch_insta_knockdown: bool = false
var punch_makes_invisible: bool = false
var invis_damage_multiplier: float = 1.0
var punch_self_damages: bool = false
var proj_fires_airborne: bool = false
var whataboutism_blocks: bool = false
var disable_attacks_airborne: bool = false
var flypunch_teleports: bool = false
var kick_teleports_behind: bool = false
var gong_hits_everywhere: bool = false
var passive_damage_per_second: int = 0
var _passive_damage_cooldown: int = 0
var flykick_forward: bool = false
var fires_projectile: bool = false

# Projectile runtime state
var _proj_cfg = null  # ProjectileConfig
var _projs: Array = []
var _proj_pool: int = 0
var _proj_next: int = 0
var _proj_pending_is_kick: bool = false
var _proj_pending_is_flypunch: bool = false
var _proj_walk_fire_cooldown: int = 0

export var action_left: String = "p1_left"
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

signal whataboutism_triggered

var state = State.NORMAL
var max_health := 100.0
var health: float = 100.0
var is_defeated := false
var hit_count := 0
var _hit_ticks: int = 0
var _attacking := false
var _opponent: KinematicBody2D
var _ipman_target: KinematicBody2D
var _ipman_lookup_done: bool = false
var _health_bar: ProgressBar
var frozen: bool = false setget _set_frozen
var _punch_arm_extension: float = PUNCH_ARM_EXTENSION
var _start_position: Vector2
var velocity: Vector2 = Vector2.ZERO
var _hitstop_ticks: int = 0
var _knockback_x: float = 0.0
var _block_stun_ticks: int = 0
var _blocked_punch: bool = false
var _current_anim: String = ""
var stay_down: bool = false
var input_disabled: bool = false
var _current_combo_count: int = 0
var _whataboutism_block_count: int = 0
var _whataboutism_window_ticks: int = 0
var _whataboutism_window_ticks_max: int = COMBO_INPUT_WINDOW_TICKS
var _pending_whataboutism: bool = false
var _pending_whataboutism_pos: Vector2 = Vector2.ZERO
var _pending_whataboutism_damage: int = 0
var _pending_whataboutism_knockback: float = 1.0
var _veli_kick_icon: Sprite
var _invis_ticks: int = 0
const INVIS_MAX_TICKS: int = 180

# Cached input snapshot to avoid redundant Input.is_action_pressed() calls
var _inp_left: bool = false
var _inp_right: bool = false
var _inp_down: bool = false
var _inp_jump_jp: bool = false
var _inp_punch_jp: bool = false
var _inp_kick_jp: bool = false

var LOBSTER_FONT_28: BitmapFont = load("res://assets/fonts/lobster28.fnt")

# Physics-tick timing
var _anim_hit_fired: bool = false
var _attack_hit_tick: int = -1
var _proj_launch_fired: bool = false
var _proj_launch_tick: int = -1
var _proj_launch_count: int = 0
var _attack_tick_count: int = 0
var _attack_is_kick: bool = false
var _lunge_upwards_kick: bool = false
var _anim_ticks_remaining: int = -1
var _anim_metadata: Dictionary = {}


class ProjectileConfig:
	var speed: int = 0
	var damage: int = 10
	var hit_radius: int = 0
	var y_tolerance: int = 0
	var lifetime_ticks: int = 0
	var spawn_x_offset: int = 70
	var spawn_y_offset: int = 200
	var scale_base: float = 3.0
	var scale_kick: float = 0.0
	var anim_hframes: int = 1
	var anim_vframes: int = 1
	var anim_fps: int = 8
	var anim_hframes_kick: int = 1
	var anim_vframes_kick: int = 1
	var anim_fps_kick: int = 8
	var texture_punch: Texture
	var texture_kick: Texture
	var lottery_mode: bool = false
	var fires_on_punch: bool = false
	var fires_on_kick: bool = false
	var fires_on_walk: bool = false
	var fires_on_flypunch: bool = false
	var walk_fire_rate: int = 10
	var kick_upwards: bool = false


class Projectile:
	var active: bool = false
	var x: float = 0.0
	var y: float = 0.0
	var vy: float = 0.0
	var dir: int = 1
	var lifetime: int = 0
	var is_kick: bool = false
	var value: int = 0
	var is_heal: bool = false
	var sprite = null
	var label = null


func _ready() -> void:
	_proj_cfg = ProjectileConfig.new()
	_start_position = global_position
	add_to_group("players")
	collision_mask |= 2
	if face_left:
		anim.flip_h = true
	if health_bar_path:
		_health_bar = get_node(health_bar_path)
		_health_bar.max_value = max_health
		_health_bar.value = max_health


func apply_character(def: CharacterDef) -> void:
	display_name = def.display_name
	anim.frames = def.get_sprite_frames()
	anim.modulate = def.modulate
	_punch_arm_extension = def.punch_arm_extension
	speed = def.speed
	jump_speed = def.jump_speed
	jump_velocity = def.jump_velocity
	punch_damage = def.punch_damage
	kick_damage = def.kick_damage
	block_damage_modifier = def.block_damage_modifier
	max_health = def.max_health
	health = max_health
	if _health_bar: _health_bar.max_value = max_health
	flykick_forward = def.flykick_forward
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
	walk_self_heal = def.walk_self_heal
	kick_knockback_multiplier = def.kick_knockback_multiplier
	punch_insta_knockdown = def.punch_insta_knockdown
	fires_projectile = def.fires_projectile
	_proj_cfg = ProjectileConfig.new()
	_proj_cfg.fires_on_punch = def.proj_fires_on_punch
	_proj_cfg.fires_on_kick = def.proj_fires_on_kick
	_proj_cfg.fires_on_walk = def.proj_fires_on_walk
	_proj_cfg.fires_on_flypunch = def.proj_fires_on_flypunch
	_proj_cfg.walk_fire_rate = def.proj_walk_fire_rate
	_proj_cfg.texture_punch = def.get_proj_texture()
	_proj_cfg.texture_kick = def.get_proj_texture_kick()
	_proj_cfg.scale_base = def.proj_scale
	_proj_cfg.scale_kick = def.proj_scale_kick
	_proj_cfg.anim_hframes_kick = def.proj_anim_hframes_kick
	_proj_cfg.anim_vframes_kick = def.proj_anim_vframes_kick
	_proj_cfg.anim_fps_kick = def.proj_anim_fps_kick
	_proj_cfg.speed = def.proj_speed
	_proj_cfg.damage = def.proj_damage
	_proj_cfg.hit_radius = def.proj_hit_radius
	_proj_cfg.y_tolerance = def.proj_y_tolerance
	_proj_cfg.kick_upwards = def.proj_kick_upwards
	_proj_cfg.lifetime_ticks = def.proj_lifetime_ticks
	_proj_cfg.spawn_x_offset = def.proj_spawn_x_offset
	_proj_cfg.spawn_y_offset = def.proj_spawn_y_offset
	_proj_cfg.anim_hframes = def.proj_anim_hframes
	_proj_cfg.anim_vframes = def.proj_anim_vframes
	_proj_cfg.anim_fps = def.proj_anim_fps
	_proj_cfg.lottery_mode = def.proj_lottery_mode

	_init_projectile_pool(def.proj_pool)

	if display_name == "Veli":
		if not _veli_kick_icon:
			_veli_kick_icon = Sprite.new()
			_veli_kick_icon.texture = load("res://assets/veli/empathetic-kick.png")
			_veli_kick_icon.visible = false
			_veli_kick_icon.scale = Vector2(VELI_ICON_SCALE, VELI_ICON_SCALE)
			_veli_kick_icon.z_index = 5
			add_child(_veli_kick_icon)
		_veli_kick_icon.position = Vector2(0, VELI_ICON_Y_OFFSET)
	elif _veli_kick_icon:
		_veli_kick_icon.visible = false

	fall_gravity_scale = def.fall_gravity_scale
	invulnerable_when_airborne = def.invulnerable_when_airborne
	partial_loop_jump = def.partial_loop_jump
	punch_pulls_opponent = def.punch_pulls_opponent
	punch_makes_invisible = def.punch_makes_invisible
	invis_damage_multiplier = def.invis_damage_multiplier
	punch_self_damages = def.punch_self_damages
	proj_fires_airborne = def.proj_fires_airborne
	punch_knockback_multiplier = def.punch_knockback_multiplier
	whataboutism_blocks = def.whataboutism_blocks
	_whataboutism_window_ticks_max = def.whataboutism_window_ticks
	disable_attacks_airborne = def.disable_attacks_airborne
	flypunch_teleports = def.flypunch_teleports
	kick_teleports_behind = def.kick_teleports_behind
	gong_hits_everywhere = def.gong_hits_everywhere
	passive_damage_per_second = def.passive_damage_per_second
	_passive_damage_cooldown = 0
	anim.scale = Vector2(SPRITE_BASE_SCALE, SPRITE_BASE_SCALE) * def.sprite_scale
	anim.offset = Vector2(0, SPRITE_Y_OFFSET) + def.sprite_offset
	_cache_all_animation_data()
	anim.play("idle")


func _init_projectile_pool(pool_size: int) -> void:
	for p in _projs:
		p.sprite.queue_free()
		if p.label: p.label.queue_free()
	_projs.clear()
	_proj_next = 0
	_proj_pool = pool_size
	var shared_font: BitmapFont = null
	if _proj_cfg.lottery_mode and _proj_pool > 0:
		shared_font = LOBSTER_FONT_28
	for _i in range(_proj_pool):
		var p = Projectile.new()
		p.sprite = Sprite.new()
		p.sprite.set_as_toplevel(true)
		p.sprite.visible = false
		add_child(p.sprite)
		if shared_font != null:
			p.label = Label.new()
			p.label.set_as_toplevel(true)
			p.label.visible = false
			p.label.add_font_override("font", shared_font)
			add_child(p.label)
		_projs.append(p)


func _cache_all_animation_data() -> void:
	_anim_metadata.clear()
	if not anim.frames: return
	var phz := Engine.iterations_per_second
	for anim_name in anim.frames.get_animation_names():
		var variants := [["", 1.0]]
		if (anim_name == "punch" or anim_name == "body_punch") and proj_fires_airborne:
			variants = [["", punch_speed_scale], ["_air", flypunch_speed_scale]]
		elif anim_name == "flypunch" and _proj_cfg.fires_on_flypunch:
			variants = [["", flypunch_speed_scale]]
		else:
			var ss := 1.0
			if anim_name == "kick": ss = kick_speed_scale
			elif anim_name == "flykick": ss = flykick_speed_scale
			elif anim_name == "punch" or anim_name == "body_punch": ss = punch_speed_scale
			elif anim_name == "flypunch": ss = flypunch_speed_scale
			variants = [["", ss]]
		for v in variants:
			var suffix: String = v[0]
			var ss: float = v[1]
			var data := {"speed_scale": ss, "hit_tick": -1, "proj_tick": -1, "total_ticks": -1, "is_kick": false}
			var fps_raw := anim.frames.get_animation_speed(anim_name) * ss
			var fps_int := max(1, int(round(fps_raw)))
			var target_frame := -1
			if anim_name == "punch" or anim_name == "flypunch": target_frame = 1
			elif anim_name == "bodypunch": target_frame = 2
			elif anim_name == "kick" or anim_name == "flykick":
				target_frame = 2
				data.is_kick = true
			if target_frame >= 0: data.hit_tick = (target_frame * phz + fps_int - 1) / fps_int
			var _fires: bool = (fires_projectile and ((_proj_cfg.fires_on_punch and anim_name == "punch") or (_proj_cfg.fires_on_kick and anim_name == "kick") or (_proj_cfg.fires_on_flypunch and anim_name == "flypunch")))
			if _fires:
				var proj_frame := 3 if anim_name == "punch" else 2
				data.proj_tick = (proj_frame * phz + fps_int - 1) / fps_int
			if not anim.frames.get_animation_loop(anim_name):
				var fc := anim.frames.get_frame_count(anim_name)
				data.total_ticks = (fc * phz + fps_int - 1) / fps_int
			_anim_metadata[anim_name + suffix] = data


func reset_for_round() -> void:
	health = max_health
	is_defeated = false
	state = State.NORMAL
	hit_count = 0
	_hit_ticks = 0
	_attacking = false
	velocity = Vector2.ZERO
	_knockback_x = 0.0
	_hitstop_ticks = 0
	_block_stun_ticks = 0
	_current_anim = ""
	stay_down = false
	input_disabled = false
	_current_combo_count = 0
	_blocked_punch = false
	_opponent = null
	_proj_next = 0
	for p in _projs:
		p.active = false
		p.lifetime = 0
		p.sprite.visible = false
		if p.label: p.label.visible = false
	_invis_ticks = 0
	_passive_damage_cooldown = 0
	anim.modulate.a = 1.0
	if _veli_kick_icon:
		_veli_kick_icon.visible = false
	_anim_hit_fired = false
	_attack_hit_tick = -1
	_attack_tick_count = 0
	_attack_is_kick = false
	_anim_ticks_remaining = -1
	_proj_launch_fired = false
	_proj_launch_tick = -1
	_proj_launch_count = 0
	_proj_pending_is_flypunch = false
	global_position = _start_position
	if _health_bar: _health_bar.value = health
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
		var lookup_key := anim_name
		if (anim_name == "punch" or anim_name == "body_punch") and proj_fires_airborne and not is_on_floor():
			lookup_key += "_air"
		var data: Dictionary = _anim_metadata.get(lookup_key, {})
		if not data.empty():
			anim.speed_scale = data.speed_scale
			_attack_hit_tick = data.hit_tick
			_proj_launch_tick = data.proj_tick
			_anim_ticks_remaining = data.total_ticks
			_attack_is_kick = data.is_kick
			if _proj_launch_tick >= 0:
				_proj_pending_is_kick = (anim_name == "kick")
				_proj_pending_is_flypunch = (anim_name == "flypunch")
		else:
			anim.speed_scale = 1.0
		anim.play(anim_name)

		if _veli_kick_icon:
			_veli_kick_icon.visible = false


func set_opponent(opp: KinematicBody2D) -> void:
	_opponent = opp


func _set_frozen(value: bool) -> void:
	frozen = value
	if anim: anim.playing = not value


func _move_with_floor_snap() -> Vector2:
	var snap := Vector2.ZERO
	if velocity.y >= 0.0: snap = FLOOR_SNAP
	return move_and_slide_with_snap(velocity + Vector2(_knockback_x, 0.0), snap, Vector2.UP)


func _handle_animation_finished() -> void:
	match state:
		State.HIT: state = State.NORMAL
		State.FALLEN:
			if not is_on_floor():
				_current_anim = ""
				_play_anim("falls")
				return
			if stay_down:
				anim.frame = anim.frames.get_frame_count("falls") - 1
				anim.stop()
				return
			if not is_defeated:
				state = State.GETUP
				_play_anim("getup")
		State.GETUP:
			state = State.NORMAL
			hit_count = 0
			if _opponent: _opponent._current_combo_count = 0
		_:
			if _attacking:
				_attacking = false
				if state == State.NORMAL: _play_anim("idle")


func force_getup() -> void:
	state = State.GETUP
	_play_anim("getup")


func force_punch() -> void:
	_attacking = true
	_play_anim("punch")


func force_fall() -> void:
	_enter_fallen()


func take_hit(is_kick: bool, attacker_pos: Vector2, is_counter: bool = false, damage: int = 15, knockback_multiplier: float = 1.0, no_knockdown: bool = false, force_knockdown: bool = false) -> bool:
	_end_invisibility()
	if is_defeated or state == State.GETUP: return false
	if state == State.FALLEN and is_on_floor(): return false
	if invulnerable_when_airborne and not is_on_floor(): return false
	if force_knockdown: 
		_enter_fallen()
		return true
	var to_opp_block := 0.0
	if _opponent: to_opp_block = _opponent.global_position.x - global_position.x
	var is_blocking = _check_blocking(to_opp_block)
	if is_counter: damage = int(damage * COUNTER_HIT_BONUS)
	var block_broken := false
	if is_blocking:
		if is_kick:
			block_broken = true
			_apply_impact(attacker_pos, knockback_multiplier)
		else:
			damage = int(damage * block_damage_modifier)
			_apply_impact(attacker_pos, knockback_multiplier)
			state = State.BLOCKING
			_attacking = false
			_block_stun_ticks = BLOCK_STUN_TICKS
			_blocked_punch = true
			_play_anim("block")
			if anim.frame >= 1:
				anim.frame = 1
				anim.stop()
			if _opponent: _opponent._current_combo_count = 0
			_handle_whataboutism_on_block()
	else:
		_apply_impact(attacker_pos, knockback_multiplier)
		hit_count += 1
		_hit_ticks = HIT_WINDOW_TICKS
		_current_combo_count = 0
	health = max(0, health - damage)
	if _health_bar: _health_bar.value = health
	if health <= 0:
		_enter_defeated()
		return true
	elif not is_blocking or block_broken:
		if state == State.FALLEN:
			anim.stop()
			anim.frame = 2
			velocity.y = HIT_BOUNCE_VELOCITY
		elif no_knockdown:
			pass
		elif block_broken or not is_on_floor() or hit_count >= HIT_COMBO_THRESHOLD:
			var launch = is_on_floor() and hit_count >= HIT_COMBO_THRESHOLD and not block_broken
			hit_count = 0
			_hit_ticks = 0
			_enter_fallen()
			if launch: velocity.y = LAUNCH_VELOCITY
		else:
			_enter_hit()
	_hitstop_ticks = HITSTOP_TICKS
	return true


func _handle_whataboutism_on_block() -> void:
	if whataboutism_blocks:
		_whataboutism_window_ticks = _whataboutism_window_ticks_max
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


func _check_blocking(to_opp: float) -> bool:
	if to_opp > 0 and _inp_left: return true
	if to_opp < 0 and _inp_right: return true
	return false


func _apply_impact(attacker_pos: Vector2, multiplier: float) -> void:
	var dir = (global_position.x - attacker_pos.x)
	if dir == 0: dir = -1.0 if anim.flip_h else 1.0
	dir = sign(dir)
	_knockback_x = dir * KNOCKBACK_FORCE * multiplier


func _apply_pull(attacker_pos: Vector2) -> void:
	if is_defeated or state == State.GETUP: return
	if invulnerable_when_airborne and not is_on_floor(): return
	var dir = sign(attacker_pos.x - global_position.x)
	_knockback_x = dir * KNOCKBACK_FORCE
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
	_apply_impact(attacker_pos, LAUNCH_KNOCKBACK_MULT)
	velocity.y = STRONG_LAUNCH_VELOCITY
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


func _do_kick_teleport_behind() -> void:
	if _opponent == null: return
	var my_facing = -1.0 if anim.flip_h else 1.0
	var target_x: float = global_position.x - my_facing * KICK_TELEPORT_OFFSET
	var target_y: float = global_position.y

	# Clamp to map bounds so the opponent doesn't teleport through walls
	var clamped_x: float = clamp(target_x, MAP_LEFT_BOUND, MAP_RIGHT_BOUND)
	var clamped_y: float = clamp(target_y, MAP_TOP_BOUND, MAP_BOTTOM_BOUND)

	# Only teleport if the target is within bounds
	if abs(target_x - clamped_x) < TELEPORT_SNAP_TOLERANCE and abs(target_y - clamped_y) < TELEPORT_SNAP_TOLERANCE:
		_opponent.global_position.x = clamped_x
		_opponent.global_position.y = clamped_y
		_opponent.velocity.x = 0.0


func _do_flypunch_teleport() -> void:
	if _opponent == null: return
	# "behind" = the side the opponent is NOT facing
	var opp_facing := -1.0 if _opponent.anim.flip_h else 1.0
	var target_x := _opponent.global_position.x - opp_facing * FLYPUNCH_TELEPORT_OFFSET
	var target_y := _opponent.global_position.y

	# Clamp to map bounds so Drago doesn't teleport through walls
	var clamped_x := clamp(target_x, MAP_LEFT_BOUND, MAP_RIGHT_BOUND)
	var clamped_y := clamp(target_y, MAP_TOP_BOUND, MAP_BOTTOM_BOUND)

	# Only teleport if the target is within bounds
	if abs(target_x - clamped_x) < TELEPORT_SNAP_TOLERANCE and abs(target_y - clamped_y) < TELEPORT_SNAP_TOLERANCE:
		global_position.x = clamped_x
		global_position.y = clamped_y
		velocity.y = 0.0
		anim.flip_h = _opponent.anim.flip_h


func _try_hit_opponent(is_kick: bool) -> void:
	if _opponent == null: return
	if is_kick and kick_damage == 0:
		if kick_heals_self > 0:
			health = min(max_health, health + kick_heals_self)
			if _health_bar: _health_bar.value = health
		return

	var y_diff = abs(global_position.y - _opponent.global_position.y)
	var y_threshold = HIT_Y_THRESHOLD_AIRBORNE if (_opponent.state == State.FALLEN and not _opponent.is_on_floor()) else HIT_Y_THRESHOLD_STANDING
	if y_diff > y_threshold and not gong_hits_everywhere: return
	var facing_dir  := -1.0 if anim.flip_h else 1.0
	var to_opponent := _opponent.global_position.x - global_position.x
	if sign(to_opponent) != sign(facing_dir) and not gong_hits_everywhere: return
	if punch_pulls_opponent and not is_kick:
		if abs(to_opponent) > PULL_RANGE: return
		_opponent._apply_pull(global_position)
		_hitstop_ticks = HITSTOP_TICKS
		emit_signal("hit_landed", false, 0)
		return
	var extension   := KICK_LEG_EXTENSION if is_kick else _punch_arm_extension
	var hit_x       := global_position.x + facing_dir * extension
	var fist_to_opp := abs(hit_x - _opponent.global_position.x)
	if fist_to_opp > HIT_TARGET_RADIUS and not (gong_hits_everywhere and not is_kick): return

	var is_counter  = _opponent._attacking
	var _dmg_mult: float = invis_damage_multiplier if _invis_ticks > 0 else 1.0
	var no_knockdown = gong_hits_everywhere and not is_kick
	var hit_registered: bool = _opponent.take_hit(is_kick, global_position, is_counter, int((kick_damage if is_kick else punch_damage) * _dmg_mult), kick_knockback_multiplier if is_kick else punch_knockback_multiplier, no_knockdown, false if is_kick else punch_insta_knockdown)
	if not hit_registered: return

	if is_kick and kick_heals_self > 0:
		health = min(max_health, health + kick_heals_self)
		if _health_bar: _health_bar.value = health

	if is_kick and _veli_kick_icon:
		_veli_kick_icon.visible = true
		var side = -1.0 if anim.flip_h else 1.0
		_veli_kick_icon.position = Vector2(side * VELI_ICON_X_SIDE, VELI_ICON_Y_OFFSET)

	_hitstop_ticks = HITSTOP_TICKS
	if punch_makes_invisible and not is_kick:
		_invis_ticks = INVIS_MAX_TICKS
		anim.modulate.a = 0.0


	if kick_teleports_behind and is_kick and not _opponent.is_defeated:
		_do_kick_teleport_behind()
	if launch_punch and not is_kick and not _opponent.is_defeated:
		_opponent._enter_launched(global_position)
	if combos_enabled and not no_knockdown: _current_combo_count += 1
	var show_combo = combos_enabled and _current_combo_count >= 2
	emit_signal("hit_landed", is_kick, _current_combo_count if show_combo else 0)


func _launch_projectile() -> void:
	var cfg = _proj_cfg
	var facing_dir := -1 if anim.flip_h else 1
	var i := _proj_next
	_proj_next = (_proj_next + 1) % _proj_pool
	var p = _projs[i]
	p.active = true
	p.is_kick = _proj_pending_is_kick
	p.dir = facing_dir
	p.x = global_position.x + facing_dir * cfg.spawn_x_offset
	p.y = (_start_position.y - cfg.spawn_y_offset) if _proj_pending_is_flypunch else (global_position.y - cfg.spawn_y_offset)
	p.vy = float(-cfg.speed) if cfg.kick_upwards and _proj_pending_is_kick else 0.0
	p.lifetime = 0
	if cfg.lottery_mode:
		var values = LOTTERY_DAMAGE_VALUES
		p.value = values[randi() % 4]
		p.is_heal = randi() % 2 == 0
		p.label.text = ("+" if p.is_heal else "-") + str(p.value)
		p.label.add_color_override("font_color", Color(0.2, 1.0, 0.2, 1.0) if p.is_heal else Color(1.0, 0.2, 0.2, 1.0))
	if _proj_pending_is_kick and cfg.texture_kick:
		p.sprite.texture = cfg.texture_kick
		p.sprite.hframes = cfg.anim_hframes_kick
		p.sprite.vframes = cfg.anim_vframes_kick
		var sk: float = cfg.scale_kick if cfg.scale_kick > 0.0 else cfg.scale_base
		p.sprite.scale = Vector2(sk, sk)
	else:
		p.sprite.texture = cfg.texture_punch
		p.sprite.hframes = cfg.anim_hframes
		p.sprite.vframes = cfg.anim_vframes
		p.sprite.scale = Vector2(cfg.scale_base, cfg.scale_base)


func _action_pressed(action: String) -> bool:
	if input_disabled: return false
	return Input.is_action_pressed(action)


func _action_just_pressed(action: String) -> bool:
	if input_disabled: return false
	return Input.is_action_just_pressed(action)


func _physics_process(delta: float) -> void:
	if frozen: return

	var is_on_floor_t = is_on_floor()
	_handle_pending_abilities(is_on_floor_t)
	if state == State.NORMAL and _pending_whataboutism: return

	var opp_pos := Vector2.ZERO
	var opp_attacking := false
	if _opponent:
		opp_pos = _opponent.global_position
		opp_attacking = _opponent._attacking

	var inp := _get_input_snapshot()
	_inp_left = inp.left
	_inp_right = inp.right
	var to_opp := 0.0
	var is_blocking_input := false
	if _opponent:
		to_opp = opp_pos.x - global_position.x
		if (to_opp > 0 and inp.left) or (to_opp < 0 and inp.right): is_blocking_input = true

	_handle_attack_input(inp, is_on_floor_t, is_blocking_input)
	if _tick_timers(): return

	if not is_on_floor_t:
		var grav_scale := fall_gravity_scale if state == State.NORMAL else 1.0
		velocity.y += GRAVITY * (FAST_FALL_MULTIPLIER if inp.down else 1.0) * grav_scale * delta

	if state == State.FALLEN and _current_anim == "jump" and velocity.y >= 0:
		_current_anim = ""
		_play_anim("falls")

	if state == State.FALLEN or state == State.GETUP or state == State.BLOCKING:
		velocity.x = 0.0
		velocity = _move_with_floor_snap()
		return

	var direction := float(inp.right) - float(inp.left)
	var dist_to_opp := abs(to_opp)
	var should_block_visually := is_blocking_input and opp_attacking and dist_to_opp < PROXIMITY_BLOCK_RANGE
	velocity.x = _calculate_velocity_x(inp, is_on_floor_t, to_opp, opp_attacking, dist_to_opp)
	velocity = _move_with_floor_snap()
	_apply_ipman_attraction()

	_update_animation_state(direction, is_on_floor_t, should_block_visually, to_opp, dist_to_opp)


func _handle_attack_input(inp: InputSnapshot, is_on_floor_t: bool, is_blocking_input: bool) -> void:
	if state == State.BLOCKING and _blocked_punch:
		if inp.jump_jp and is_on_floor_t:
			_block_stun_ticks = 0
			_blocked_punch = false
			state = State.NORMAL

	if state == State.NORMAL and _hitstop_ticks == 0:
		if not _attacking and not is_blocking_input and not (disable_attacks_airborne and not is_on_floor_t):
			if inp.punch_jp:
				_attacking = true
				if not is_on_floor_t: _play_anim("punch" if proj_fires_airborne else "flypunch")
				else: _play_anim("bodypunch" if body_punch_enabled else "punch")
			elif inp.kick_jp:
				_attacking = true
				_play_anim("flykick" if not is_on_floor_t else "kick")
		if inp.jump_jp and is_on_floor_t and not _attacking: velocity.y = jump_velocity


func _tick_timers() -> bool:
	if _anim_ticks_remaining > 0:
		_anim_ticks_remaining -= 1
		if _anim_ticks_remaining == 0: _handle_animation_finished()

	if _hitstop_ticks > 0:
		_hitstop_ticks -= 1
		return true

	if _attacking and not _anim_hit_fired and _attack_hit_tick >= 0:
		_attack_tick_count += 1
		if _attack_tick_count >= _attack_hit_tick:
			_anim_hit_fired = true
			if flypunch_teleports and _current_anim == "flypunch":
				_do_flypunch_teleport()
			elif _proj_cfg.fires_on_flypunch and _current_anim == "flypunch":
				pass
			else:
				var _is_kick_attack := _attack_is_kick or _current_anim == "flykick"
				if punch_self_damages and not _is_kick_attack:
					health -= PUNCH_SELF_DAMAGE
					if _health_bar: _health_bar.value = health
					if health <= 0 and not is_defeated: _enter_defeated()
				_try_hit_opponent(_is_kick_attack)

	if _attacking and not _proj_launch_fired and _proj_launch_tick >= 0:
		_proj_launch_count += 1
		if _proj_launch_count >= _proj_launch_tick:
			_proj_launch_fired = true
			_launch_projectile()

	if fires_projectile:
		_process_projectiles(_opponent.global_position if _opponent else Vector2.ZERO)

	if _proj_cfg.fires_on_walk and _proj_walk_fire_cooldown > 0:
		_proj_walk_fire_cooldown -= 1

	if _hit_ticks > 0:
		_hit_ticks -= 1
		if _hit_ticks == 0:
			hit_count = 0
			if _opponent: _opponent._current_combo_count = 0

	if _invis_ticks > 0:
		_invis_ticks -= 1
		if _invis_ticks == 0: anim.modulate.a = 1.0

	# Passive damage: deal damage every second (60 physics ticks)
	if passive_damage_per_second > 0 and _opponent:
		_passive_damage_cooldown += 1
		if _passive_damage_cooldown >= Engine.iterations_per_second:
			_passive_damage_cooldown = 0
			var h = max(0, _opponent.health - passive_damage_per_second)
			_opponent.health = h
			if _health_bar: _opponent._health_bar.value = h
			if _opponent.health <= 0 and not _opponent.is_defeated:
				_opponent._enter_defeated()
				return true

	_knockback_x *= KNOCKBACK_DECAY_FACTOR

	if _block_stun_ticks > 0:
		_block_stun_ticks -= 1
		if _block_stun_ticks == 0:
			state = State.NORMAL
			_blocked_punch = false

	if _whataboutism_window_ticks > 0:
		_whataboutism_window_ticks -= 1
		if _whataboutism_window_ticks == 0: _whataboutism_block_count = 0

	return false


func _calculate_velocity_x(inp: InputSnapshot, is_on_floor_t: bool, to_opp: float, opp_attacking: bool, dist_to_opp: float) -> float:
	var direction := float(inp.right) - float(inp.left)
	var is_walking_back := (direction != 0 and sign(direction) != sign(to_opp)) if to_opp != 0 else false
	var is_blocking_input := (to_opp > 0 and inp.left) or (to_opp < 0 and inp.right)
	var should_block_visually := is_blocking_input and opp_attacking and dist_to_opp < PROXIMITY_BLOCK_RANGE

	if state == State.HIT and should_block_visually and is_on_floor_t:
		return 0.0
	elif _attacking and (is_on_floor_t or (_lunge_upwards_kick and _attack_is_kick)) and not fires_projectile:
		var lunge := 1.0 if not anim.flip_h else -1.0
		var lunge_scale := kick_lunge_scale if _attack_is_kick else punch_lunge_scale
		if _lunge_upwards_kick and _attack_is_kick and is_on_floor_t: velocity.y = -(speed * LUNGE_VERTICAL_FRACTION * lunge_scale)
		return lunge * (speed * LUNGE_HORIZONTAL_FRACTION * lunge_scale)
	elif _attacking and flykick_forward and _current_anim == "flykick":
		var lunge := 1.0 if not anim.flip_h else -1.0
		return lunge * FLYKICK_FORWARD_SPEED
	else:
		var current_speed := speed * (WALK_BACK_SPEED_MULT if is_walking_back else 1.0)
		if velocity.y != 0: current_speed = jump_speed
		return direction * current_speed


func _apply_ipman_attraction() -> void:
	if display_name == "IpMan": return
	if not _ipman_lookup_done:
		_ipman_lookup_done = true
		for p in get_tree().get_nodes_in_group("players"):
			var other: KinematicBody2D = p
			if other != self and other.display_name == "IpMan":
				_ipman_target = other
				break
	if _ipman_target != null and is_instance_valid(_ipman_target):
		var to_ipman: Vector2 = _ipman_target.global_position - global_position
		if to_ipman.length() > 1.0:
			global_position += to_ipman.normalized() * IPMAN_ATTRACTION_SPEED


func _handle_pending_abilities(is_on_floor_t: bool) -> void:
	if _pending_whataboutism:
		_pending_whataboutism = false
		_end_invisibility()
		if not is_defeated and not (state == State.FALLEN and is_on_floor_t):
			_apply_impact(_pending_whataboutism_pos, _pending_whataboutism_knockback)
			health = max(0, health - _pending_whataboutism_damage)
			if _health_bar: _health_bar.value = health
			if health <= 0: _enter_defeated()
			else: _enter_fallen()
			_hitstop_ticks = HITSTOP_TICKS


# Reusable input struct - avoids Dictionary allocation every physics tick (Pi 3 GC pressure)
class InputSnapshot:
	var left: bool = false
	var right: bool = false
	var down: bool = false
	var jump_jp: bool = false
	var punch_jp: bool = false
	var kick_jp: bool = false

var _input_cache = InputSnapshot.new()

func _get_input_snapshot() -> InputSnapshot:
	if input_disabled:
		_input_cache.left = false; _input_cache.right = false; _input_cache.down = false
		_input_cache.jump_jp = false; _input_cache.punch_jp = false; _input_cache.kick_jp = false
	else:
		_input_cache.left     = Input.is_action_pressed(action_left)
		_input_cache.right    = Input.is_action_pressed(action_right)
		_input_cache.down     = Input.is_action_pressed(action_down)
		_input_cache.jump_jp  = Input.is_action_just_pressed(action_jump)
		_input_cache.punch_jp = Input.is_action_just_pressed(action_punch)
		_input_cache.kick_jp  = Input.is_action_just_pressed(action_kick)
	return _input_cache




func _deactivate_proj(p) -> void:
	p.active = false
	p.sprite.visible = false
	if p.label: p.label.visible = false


func _process_projectiles(opp_pos: Vector2) -> void:
	var phz := Engine.iterations_per_second
	var cfg = _proj_cfg
	var opp_x: float = opp_pos.x
	var opp_y: float = opp_pos.y
	var self_x: float = global_position.x
	var self_y: float = global_position.y

	var pending_self_heal: int = 0
	var pending_self_damage: int = 0
	var pending_self_damage_pos: Vector2 = Vector2.ZERO
	var pending_opp_heal: int = 0
	var pending_opp_damage: int = 0
	var pending_opp_damage_pos: Vector2 = Vector2.ZERO

	for p in _projs:
		if not p.active:
			continue

		p.x += p.dir * cfg.speed
		p.y += p.vy
		p.lifetime += 1

		if p.lifetime > cfg.lifetime_ticks or p.x < PROJ_OUT_BOUND_LEFT or p.x > PROJ_OUT_BOUND_RIGHT:
			_deactivate_proj(p)
			continue

		if cfg.lottery_mode:
			var sdx := abs(p.x - self_x)
			var sdy := abs(p.y - self_y)
			if sdx < cfg.hit_radius and sdy < cfg.y_tolerance and self_y + PROJ_GROUND_TOLERANCE >= p.y:
				_deactivate_proj(p)
				if p.is_heal:
					pending_self_heal += p.value
				else:
					pending_self_damage += p.value
					pending_self_damage_pos = Vector2(p.x, p.y)
				continue

		var dx := abs(p.x - opp_x)
		var dy := abs(p.y - opp_y)
		if dx < cfg.hit_radius and dy < cfg.y_tolerance and opp_y + PROJ_GROUND_TOLERANCE >= p.y:
			_deactivate_proj(p)
			if cfg.lottery_mode:
				if p.is_heal:
					pending_opp_heal += p.value
				else:
					pending_opp_damage += p.value
					pending_opp_damage_pos = Vector2(p.x, p.y)
			else:
				var registered: bool = _opponent.take_hit(false, Vector2(p.x, p.y), false, cfg.damage)
				if registered:
					_hitstop_ticks = HITSTOP_TICKS
					emit_signal("hit_landed", false, 0)
			continue

		p.sprite.visible = true
		p.sprite.global_position = Vector2(p.x, p.y)
		p.sprite.flip_h = (p.dir < 0)

		if cfg.lottery_mode and p.label:
			p.label.visible = true
			p.label.rect_global_position = Vector2(p.x, p.y - 30)

		var hf: int = cfg.anim_hframes_kick if p.is_kick else cfg.anim_hframes
		var vf: int= cfg.anim_vframes_kick if p.is_kick else cfg.anim_vframes
		var fps: int= cfg.anim_fps_kick if p.is_kick else cfg.anim_fps
		if hf * vf > 1:
			p.sprite.frame = (p.lifetime * fps / phz) % (hf * vf)

	if pending_self_heal > 0:
		health = min(max_health, health + pending_self_heal)
		if _health_bar: _health_bar.value = health
	if pending_self_damage > 0:
		take_hit(false, pending_self_damage_pos, false, pending_self_damage)
	if _opponent:
		if pending_opp_heal > 0:
			_opponent.health = min(_opponent.max_health, _opponent.health + pending_opp_heal)
			if _opponent._health_bar: _opponent._health_bar.value = _opponent.health
		if pending_opp_damage > 0:
			var registered: bool = _opponent.take_hit(false, pending_opp_damage_pos, false, pending_opp_damage)
			if registered:
				_hitstop_ticks = HITSTOP_TICKS
				emit_signal("hit_landed", false, 0)


func _update_animation_state(direction: float, is_on_floor_t: bool, should_block_visually: bool, to_opp: float, dist_to_opp: float) -> void:
	if state == State.NORMAL and not _attacking:
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
			if walk_self_heal > 0 and anim.frame == 2 and not _has_healed_on_walk:
				_has_healed_on_walk = true
				health = min(max_health, health + walk_self_heal)
				if _health_bar: _health_bar.value = health
			elif walk_self_heal > 0:
				_has_healed_on_walk = false
			if _proj_cfg.fires_on_walk and _proj_walk_fire_cooldown == 0:
				_proj_pending_is_kick = false
				_launch_projectile()
				_proj_walk_fire_cooldown = _proj_cfg.walk_fire_rate
		else:
			_play_anim("idle")
	if state == State.BLOCKING and _current_anim != "block":
		_play_anim("block")
		if anim.frame >= 1:
			anim.frame = 1
			anim.stop()
	if not _attacking and is_on_floor_t and (state == State.NORMAL or state == State.BLOCKING):
		if _opponent and dist_to_opp > FLIP_DIRECTION_THRESHOLD:
			anim.flip_h = to_opp < 0

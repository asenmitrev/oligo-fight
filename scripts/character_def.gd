extends Resource

export var id: String = ""
export var display_name: String = ""
export var sprite_frames_path: String = ""
export var modulate: Color = Color(1, 1, 1, 1)
export var preview_frames_path: String = ""

# Cached resources — populated on first call to ensure_loaded()
var _sprite_frames: SpriteFrames = null
var _preview_frames: SpriteFrames = null
export var punch_arm_extension: float = 120.0
export var speed: float = 350.0
export var jump_speed: float = 700.0
export var jump_velocity: float = -1700.0
export var flykick_forward: bool = false
export var punch_damage: int = 15
export var kick_damage: int = 8
export var block_damage_modifier: float = 0.15
export var max_health: int = 100
export var sprite_scale: float = 1.0
export var sprite_offset: Vector2 = Vector2.ZERO
export var launch_punch: bool = false
export var combos_enabled: bool = true
export var body_punch_enabled: bool = false
export var punch_self_damages: bool = false
export var kick_speed_scale: float = 1.0
export var lunge_upwards_kick: bool = false
export var punch_speed_scale: float = 1.0
export var flykick_speed_scale: float = 1.0
export var flypunch_speed_scale: float = 1.0
export var kick_lunge_scale: float = 1.0
export var punch_lunge_scale: float = 1.0
export var kick_heals_self: int = 0
export var walk_self_heal: float = 0
export var fires_projectile: bool = false
export var proj_damage: int = 10
export var proj_fires_on_punch: bool = false
export var proj_fires_on_kick: bool = false
export var proj_fires_on_walk: bool = false
export var proj_walk_fire_rate: int = 10
export var proj_speed: int = 0
export var proj_hit_radius: int = 0
export var proj_y_tolerance: int = 0
export var proj_lifetime_ticks: int = 0
export var proj_pool: int = 0
export var proj_texture_path: String = ""
export var proj_texture_kick_path: String = ""

# Cached projectile textures
var _proj_texture: Texture = null
var _proj_texture_kick: Texture = null
export var proj_scale: float = 3.0
export var proj_scale_kick: float = 0.0
export var proj_spawn_x_offset: int = 70
export var proj_spawn_y_offset: int = 200
export var proj_anim_hframes: int = 1
export var proj_anim_vframes: int = 1
export var proj_anim_fps: int = 8
export var proj_anim_hframes_kick: int = 1
export var proj_anim_vframes_kick: int = 1
export var proj_anim_fps_kick: int = 8
export var proj_kick_upwards: bool = false
export var fall_gravity_scale: float = 1.0
export var invulnerable_when_airborne: bool = false
export var partial_loop_jump: bool = false
export var punch_pulls_opponent: bool = false
export var kick_knockback_multiplier: float = 1.0
export var punch_knockback_multiplier: float = 1.0
export var punch_makes_invisible: bool = false
export var invis_damage_multiplier: float = 1.0
export var proj_fires_airborne: bool = false
export var whataboutism_blocks: bool = false
export var whataboutism_window_ticks: int = 30
export var disable_attacks_airborne: bool = false
export var flypunch_teleports: bool = false
export var kick_teleports_behind: bool = false
export var proj_fires_on_flypunch: bool = false
export var proj_lottery_mode: bool = false


func ensure_loaded() -> void:
	# Lazy-load sprite frames
	if _sprite_frames == null and sprite_frames_path != "":
		_sprite_frames = load(sprite_frames_path) as SpriteFrames
	# Lazy-load preview frames (if different from main)
	if _preview_frames == null and preview_frames_path != "":
		_preview_frames = load(preview_frames_path) as SpriteFrames
	# Lazy-load projectile textures
	if _proj_texture == null and proj_texture_path != "":
		_proj_texture = load(proj_texture_path) as Texture
	if _proj_texture_kick == null and proj_texture_kick_path != "":
		_proj_texture_kick = load(proj_texture_kick_path) as Texture

func get_sprite_frames() -> SpriteFrames:
	ensure_loaded()
	return _sprite_frames

func get_preview_sprite_frames() -> SpriteFrames:
	ensure_loaded()
	if _preview_frames:
		return _preview_frames
	return _sprite_frames

func get_proj_texture() -> Texture:
	ensure_loaded()
	return _proj_texture

func get_proj_texture_kick() -> Texture:
	ensure_loaded()
	return _proj_texture_kick

extends Resource

export var id: String = ""
export var display_name: String = ""
export var sprite_frames: SpriteFrames
export var modulate: Color = Color(1, 1, 1, 1)
export var preview_frames: SpriteFrames
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
export var kick_speed_scale: float = 1.0
export var lunge_upwards_kick: bool = false
export var punch_speed_scale: float = 1.0
export var flykick_speed_scale: float = 1.0
export var flypunch_speed_scale: float = 1.0
export var kick_lunge_scale: float = 1.0
export var punch_lunge_scale: float = 1.0
export var kick_heals_self: int = 0
export var fires_projectile: bool = false
export var proj_damage: int = 10
export var proj_fires_on_punch: bool = false
export var proj_fires_on_kick: bool = false
export var proj_speed: int = 0
export var proj_hit_radius: int = 0
export var proj_y_tolerance: int = 0
export var proj_lifetime_ticks: int = 0
export var proj_pool: int = 0
export var proj_texture: Texture
export var proj_texture_kick: Texture
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
export var punch_makes_invisible: bool = false
export var proj_fires_airborne: bool = false
export var whataboutism_blocks: bool = false
export var disable_attacks_airborne: bool = false


func get_preview_sprite_frames() -> SpriteFrames:
	if preview_frames:
		return preview_frames
	return sprite_frames

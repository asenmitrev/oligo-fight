extends Resource

export var id: String = ""
export var display_name: String = ""
export var sprite_frames: SpriteFrames
export var modulate: Color = Color(1, 1, 1, 1)
export var preview_frames: SpriteFrames
export var punch_arm_extension: float = 120.0
export var speed: float = 350.0
export var jump_velocity: float = -1700.0
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
export var punch_speed_scale: float = 1.0
export var kick_heals_self: int = 0
export var fires_projectile: bool = false
export var proj_speed: int = 0
export var proj_hit_radius: int = 0
export var proj_y_tolerance: int = 0
export var proj_lifetime_ticks: int = 0
export var proj_pool: int = 0
export var proj_texture: Texture
export var proj_scale: float = 3.0
export var proj_spawn_x_offset: int = 70
export var proj_spawn_y_offset: int = 200
export var fall_gravity_scale: float = 1.0
export var invulnerable_when_airborne: bool = false
export var partial_loop_jump: bool = false
export var punch_pulls_opponent: bool = false
export var kick_knockback_multiplier: float = 1.0


func get_preview_sprite_frames() -> SpriteFrames:
	if preview_frames:
		return preview_frames
	return sprite_frames

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
export var on_punch_sound: AudioStream = null
export var on_kick_sound: AudioStream = null


func get_preview_sprite_frames() -> SpriteFrames:
	if preview_frames:
		return preview_frames
	return sprite_frames

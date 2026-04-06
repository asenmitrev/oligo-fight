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


func get_preview_sprite_frames() -> SpriteFrames:
	if preview_frames:
		return preview_frames
	return sprite_frames

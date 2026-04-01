extends Resource

export var id: String = ""
export var display_name: String = ""
export var sprite_frames: SpriteFrames
export var modulate: Color = Color(1, 1, 1, 1)
export var preview_frames: SpriteFrames


func get_preview_sprite_frames() -> SpriteFrames:
	if preview_frames:
		return preview_frames
	return sprite_frames

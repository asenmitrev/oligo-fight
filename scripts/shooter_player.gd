extends "res://scripts/base_player.gd"

# ShooterPlayer handles characters with projectile abilities.
# Overriding _process_ability_logic avoids checking projectile flags every frame for non-shooters.

func _process_ability_logic(opp_pos: Vector2) -> void:
	if not fires_projectile:
		return

	var phz := Engine.iterations_per_second
	var opp_x_int := int(opp_pos.x)
	var opp_y_int := int(opp_pos.y)

	for i in range(_proj_pool):
		if not _proj_active[i]:
			_proj_sprites[i].visible = false
			continue

		_proj_x[i] += _proj_dir[i] * _proj_speed
		_proj_y[i] += _proj_vy[i]
		_proj_lifetime[i] += 1

		if _proj_lifetime[i] > _proj_lifetime_ticks or _proj_x[i] < -200 or _proj_x[i] > 1500:
			_proj_active[i] = false
			_proj_sprites[i].visible = false
			continue

		var dx := abs(_proj_x[i] - opp_x_int)
		var dy := abs(_proj_y[i] - opp_y_int)
		if dx < _proj_hit_radius and dy < _proj_y_tolerance and opp_y_int >= _proj_y[i]:
			_proj_active[i] = false
			_proj_sprites[i].visible = false
			var registered: bool = _opponent.take_hit(false, Vector2(_proj_x[i], _proj_y[i]), false, _proj_damage)
			if registered:
				_hitstop_ticks = HITSTOP_TICKS
				emit_signal("hit_landed", false, 0)
			continue

		var s: Sprite = _proj_sprites[i]
		s.visible = true
		s.global_position = Vector2(_proj_x[i], _proj_y[i])
		s.flip_h = (_proj_dir[i] < 0)
		
		var is_kick_p: bool  = _proj_is_kick[i]
		var hf := _proj_anim_hframes_kick if is_kick_p else _proj_anim_hframes
		var vf := _proj_anim_vframes_kick if is_kick_p else _proj_anim_vframes
		var fps := _proj_anim_fps_kick if is_kick_p else _proj_anim_fps
		if hf * vf > 1:
			s.frame = (_proj_lifetime[i] * fps / phz) % (hf * vf)

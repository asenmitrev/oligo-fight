extends "res://scripts/base_player.gd"

# ShooterPlayer handles characters with projectile abilities.
# Overriding _process_ability_logic avoids checking projectile flags every frame for non-shooters.

func _process_ability_logic(opp_pos: Vector2) -> void:
	if not fires_projectile:
		return

	var phz := Engine.iterations_per_second
	var opp_x: float = opp_pos.x
	var opp_y: float = opp_pos.y
	var self_x: float = global_position.x
	var self_y: float = global_position.y

	for i in range(_proj_pool):
		if not _proj_active[i]:
			_proj_sprites[i].visible = false
			_proj_labels[i].visible = false
			continue

		_proj_x[i] += _proj_dir[i] * _proj_speed
		_proj_y[i] += _proj_vy[i]
		_proj_lifetime[i] += 1

		if _proj_lifetime[i] > _proj_lifetime_ticks or _proj_x[i] < -200 or _proj_x[i] > 1500:
			_proj_active[i] = false
			_proj_sprites[i].visible = false
			_proj_labels[i].visible = false
			continue

		# Self-pickup: 5q walks over their own + ticket
		if _proj_lottery_mode and _proj_is_heal[i]:
			var sdx := abs(_proj_x[i] - self_x)
			var sdy := abs(_proj_y[i] - self_y)
			if sdx < _proj_hit_radius and sdy < _proj_y_tolerance and self_y + 50 >= _proj_y[i]:
				_proj_active[i] = false
				_proj_sprites[i].visible = false
				_proj_labels[i].visible = false
				health = min(max_health, health + _proj_value[i])
				if _health_bar:
					_health_bar.value = health
				continue

		var dx := abs(_proj_x[i] - opp_x)
		var dy := abs(_proj_y[i] - opp_y)
		if dx < _proj_hit_radius and dy < _proj_y_tolerance and opp_y + 50 >= _proj_y[i]:
			_proj_active[i] = false
			_proj_sprites[i].visible = false
			_proj_labels[i].visible = false
			if _proj_lottery_mode:
				var val: int = _proj_value[i]
				if _proj_is_heal[i]:
					_opponent.health = min(_opponent.max_health, _opponent.health + val)
					if _opponent._health_bar:
						_opponent._health_bar.value = _opponent.health
				else:
					var registered: bool = _opponent.take_hit(false, Vector2(_proj_x[i], _proj_y[i]), false, val)
					if registered:
						_hitstop_ticks = HITSTOP_TICKS
						emit_signal("hit_landed", false, 0)
			else:
				var registered: bool = _opponent.take_hit(false, Vector2(_proj_x[i], _proj_y[i]), false, _proj_damage)
				if registered:
					_hitstop_ticks = HITSTOP_TICKS
					emit_signal("hit_landed", false, 0)
			continue

		var s: Sprite = _proj_sprites[i]
		s.visible = true
		s.global_position = Vector2(_proj_x[i], _proj_y[i])
		s.flip_h = (_proj_dir[i] < 0)

		var l: Label = _proj_labels[i]
		if _proj_lottery_mode:
			l.visible = true
			l.rect_global_position = Vector2(_proj_x[i], _proj_y[i] - 30)

		var is_kick_p: bool  = _proj_is_kick[i]
		var hf := _proj_anim_hframes_kick if is_kick_p else _proj_anim_hframes
		var vf := _proj_anim_vframes_kick if is_kick_p else _proj_anim_vframes
		var fps := _proj_anim_fps_kick if is_kick_p else _proj_anim_fps
		if hf * vf > 1:
			s.frame = (_proj_lifetime[i] * fps / phz) % (hf * vf)

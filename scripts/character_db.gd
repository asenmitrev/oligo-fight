extends Node

const CharacterDef = preload("res://scripts/character_def.gd")
# Paths only — resources are loaded lazily on first character select
const _veli_frames_path = "res://resources/veli_sprite_frames.tres"
const _bobe_frames_path = "res://resources/bobe_sprite_frames.tres"
const _ipman_frames_path = "res://resources/ipman_sprite_frames.tres"
const _sasho_frames_path = "res://resources/sasho_sprite_frames.tres"
const _siyana_frames_path = "res://resources/siyana_sprite_frames.tres"
const _itso_frames_path = "res://resources/itso_sprite_frames.tres"
const _crunch_frames_path = "res://resources/crunch_sprite_frames.tres"
const _rado_frames_path = "res://resources/rado_sprite_frames.tres"
const _dani_frames_path = "res://resources/dani_sprite_frames.tres"
const _yavor_frames_path = "res://resources/yavor_sprite_frames.tres"
const _drago_frames_path = "res://resources/drago_sprite_frames.tres"
const _ipman_proj_path = "res://assets/ipman/money-projectile.png"
const _siyana_proj_path = "res://assets/siyana/baby-projectile.png"
const _crunch_cupcake_path = "res://assets/crunch/cupcake.png"
const _crunch_pigeon_path = "res://assets/crunch/pigeon.png"
const _yavor_proj_path = "res://assets/yavor/fas.png"
const _q5_frames_path = "res://resources/5q_sprite_frames.tres"
const _q5_lottery_path = "res://assets/5q/lottery-ticket.png"

var _by_display_name: Dictionary = {}
var all_characters: Array = []

var JUMP_VELOCITY = -1680

func _init() -> void:
	var ipman = _make_def("ipman", "IpMan", _ipman_frames_path, Color(1, 1, 1, 1))
	ipman.punch_arm_extension = 200.0
	ipman.speed = 360.0
	ipman.punch_speed_scale = 0.5
	ipman.jump_velocity = JUMP_VELOCITY
	ipman.punch_damage = 12
	ipman.kick_damage = 9
	ipman.block_damage_modifier = 0.12
	ipman.max_health = 105
	ipman.body_punch_enabled = false
	ipman.kick_speed_scale = 1.2
	ipman.fires_projectile = true
	ipman.proj_fires_on_punch = true
	ipman.flypunch_speed_scale = 1.5
	ipman.proj_damage = 10
	ipman.proj_speed = 13
	ipman.proj_hit_radius = 75
	ipman.proj_y_tolerance = 220
	ipman.proj_lifetime_ticks = 300
	ipman.proj_pool = 6
	ipman.proj_texture_path = _ipman_proj_path
	ipman.proj_scale = 3.0
	ipman.proj_spawn_x_offset = 70
	ipman.proj_spawn_y_offset = 200
	ipman.proj_fires_airborne = true
	_register(ipman)

	#var simonka = _make_def("simonka", "Simonka", _simonka_frames, Color(1, 1, 1, 1))
	#simonka.punch_arm_extension = 140.0  # punch animation extends 20px further than Veli's
	#simonka.speed = 380.0
	#simonka.jump_velocity = JUMP_VELOCITY * 1.4
	#simonka.punch_damage = 12
	#simonka.kick_damage = 8
	#simonka.block_damage_modifier = 0.12
	#simonka.max_health = 100.0
	#simonka.sprite_scale = 0.9
	# _register(simonka)

	var veli = _make_def("veli", "Veli", _veli_frames_path, Color(1, 1, 1, 1))
	veli.speed = 320.0
	veli.jump_velocity = JUMP_VELOCITY * 0.5
	veli.punch_damage = 0
	veli.punch_pulls_opponent = true
	veli.kick_damage = 20
	veli.kick_knockback_multiplier = 3.667
	veli.block_damage_modifier = 0.18
	veli.max_health = 120.0
	veli.fall_gravity_scale = 0.15
	veli.invulnerable_when_airborne = true
	veli.partial_loop_jump = true
	veli.disable_attacks_airborne = true
	_register(veli)

	var bobe = _make_def("bobe", "Bobe", _bobe_frames_path, Color(1, 1, 1, 1))
	bobe.speed = 330.0
	bobe.jump_velocity = JUMP_VELOCITY
	bobe.punch_damage = 15
	bobe.kick_damage = 10
	bobe.block_damage_modifier = 0.18
	bobe.max_health = 115
	bobe.kick_heals_self = 8
	_register(bobe)

	var sasho = _make_def("sasho", "Sasho", _sasho_frames_path, Color(1, 1, 1, 1))
	sasho.speed = 340.0
	sasho.jump_velocity = JUMP_VELOCITY
	sasho.punch_damage = 11
	sasho.kick_damage = 16
	sasho.block_damage_modifier = 0.15
	sasho.max_health = 110.0
	sasho.punch_makes_invisible = true
	sasho.invis_damage_multiplier = 1.5
	_register(sasho)

	var siyana = _make_def("siyana", "Siyana", _siyana_frames_path, Color(1, 1, 1, 1))
	siyana.speed = 350.0
	siyana.jump_velocity = JUMP_VELOCITY
	siyana.punch_damage = 13
	siyana.kick_damage = 10
	
	siyana.block_damage_modifier = 0.15
	siyana.max_health = 105.0
	siyana.fires_projectile = true
	siyana.proj_fires_on_kick = true
	siyana.proj_damage = 25
	siyana.proj_speed = 4
	siyana.proj_hit_radius = 60
	siyana.proj_y_tolerance = 100
	siyana.proj_lifetime_ticks = 240
	siyana.proj_pool = 3
	siyana.proj_texture_path = _siyana_proj_path
	siyana.proj_scale = 1.0
	siyana.proj_spawn_x_offset = 80
	siyana.proj_spawn_y_offset = 0
	siyana.kick_speed_scale = 0.70
	siyana.proj_anim_hframes = 2
	siyana.proj_anim_vframes = 2
	siyana.proj_anim_fps = 8
	_register(siyana)

	var itso = _make_def("itso", "Itso", _itso_frames_path, Color(1, 1, 1, 1))
	itso.speed = 340.0
	itso.jump_velocity = JUMP_VELOCITY
	itso.punch_damage = 14
	itso.kick_damage = 11
	itso.block_damage_modifier = 0.15
	itso.max_health = 130
	itso.kick_lunge_scale = 8.0
	_register(itso)

	var crunch = _make_def("crunch", "Crunch", _crunch_frames_path, Color(1, 1, 1, 1))
	crunch.speed = 350.0
	crunch.jump_velocity = JUMP_VELOCITY
	crunch.punch_damage = 13
	crunch.kick_damage = 11
	crunch.block_damage_modifier = 0.15
	crunch.max_health = 105
	crunch.punch_speed_scale = 0.65
	crunch.kick_speed_scale = 0.78
	crunch.fires_projectile = true
	crunch.proj_fires_on_punch = true
	crunch.proj_fires_on_kick = true
	crunch.proj_damage = 12
	crunch.proj_speed = 11
	crunch.proj_hit_radius = 50
	crunch.proj_y_tolerance = 220
	crunch.proj_lifetime_ticks = 280
	crunch.proj_pool = 10
	crunch.proj_texture_path = _crunch_cupcake_path
	crunch.proj_scale = 4
	crunch.proj_texture_kick_path = _crunch_pigeon_path
	crunch.proj_scale_kick = 0.75
	crunch.proj_anim_hframes = 1
	crunch.proj_anim_vframes = 1
	crunch.proj_anim_fps = 8
	crunch.proj_anim_hframes_kick = 2
	crunch.proj_anim_vframes_kick = 2
	crunch.proj_anim_fps_kick = 24
	crunch.proj_kick_upwards = true
	crunch.proj_spawn_x_offset = 70
	crunch.proj_spawn_y_offset = 200
	_register(crunch)

	var rado = _make_def("rado", "Rado", _rado_frames_path, Color(1, 1, 1, 1))
	rado.speed = 340.0
	rado.jump_velocity = JUMP_VELOCITY
	rado.punch_damage = 13
	rado.kick_damage = 20 
	rado.block_damage_modifier = 0.25
	rado.max_health = 115.0
	rado.whataboutism_blocks = true
	rado.whataboutism_window_ticks = 100
	rado.lunge_upwards_kick = true
	rado.kick_lunge_scale = 6.0
	rado.walk_self_heal = 0.2
	
	_register(rado)

	var dani = _make_def("dani", "Dani", _dani_frames_path, Color(1, 1, 1, 1))
	dani.speed = 750.0
	dani.jump_speed = 350.0
	dani.jump_velocity = JUMP_VELOCITY
	dani.punch_damage = 25
	dani.kick_damage = 10
	dani.block_damage_modifier = 0.15
	dani.max_health = 105.0
	dani.flykick_forward = true
	dani.punch_speed_scale = 1.5
	dani.punch_self_damages = true
	_register(dani)

	var yavor = _make_def("yavor", "Yavor", _yavor_frames_path, Color(1, 1, 1, 1))
	yavor.speed = 350.0
	yavor.jump_velocity = JUMP_VELOCITY
	yavor.punch_damage = 13
	yavor.kick_damage = 10
	yavor.block_damage_modifier = 0.15
	yavor.max_health = 105.0
	yavor.punch_arm_extension = 160
	yavor.fires_projectile = true
	yavor.proj_fires_on_walk = true
	yavor.proj_walk_fire_rate = 50
	yavor.proj_damage = 10
	yavor.proj_speed = 0
	yavor.proj_hit_radius = 20
	yavor.proj_y_tolerance = 220
	yavor.proj_lifetime_ticks = 300
	yavor.proj_pool = 3
	yavor.proj_texture_path = _yavor_proj_path
	yavor.proj_scale = 0.2
	yavor.proj_spawn_x_offset = 70
	yavor.proj_spawn_y_offset = -50
	_register(yavor)

	var drago = _make_def("drago", "Drago", _drago_frames_path, Color(1, 1, 1, 1))
	drago.speed = 350.0
	drago.punch_arm_extension = 190.0  # punch animation extends 20px further than Veli's
	drago.jump_velocity = JUMP_VELOCITY
	drago.punch_damage = 13
	drago.kick_damage = 10
	drago.block_damage_modifier = 0.15
	drago.max_health = 105.0
	drago.flypunch_teleports = true
	drago.punch_speed_scale = 0.7
	_register(drago)

	var q5 = _make_def("5q", "5q", _q5_frames_path, Color(1, 1, 1, 1))
	q5.speed = 350.0
	q5.jump_velocity = JUMP_VELOCITY
	q5.punch_damage = 13
	q5.kick_damage = 10
	q5.kick_teleports_behind = true
	q5.block_damage_modifier = 0.15
	q5.max_health = 105.0
	q5.punch_knockback_multiplier = 4.0
	q5.fires_projectile = true
	q5.proj_fires_on_flypunch = true
	q5.proj_damage = 15
	q5.proj_speed = 0
	q5.proj_hit_radius = 30
	q5.proj_y_tolerance = 100
	q5.proj_lifetime_ticks = 600
	q5.proj_pool = 3
	q5.proj_texture_path = _q5_lottery_path
	q5.proj_scale = 0.5
	q5.proj_spawn_x_offset = 80
	q5.proj_spawn_y_offset = -95
	q5.proj_lottery_mode = true
	q5.sprite_scale = 1.1
	_register(q5)


func _make_def(id: String, display_name: String, frames_path: String, mod: Color):
	var d := CharacterDef.new()
	d.id = id
	d.display_name = display_name
	d.sprite_frames_path = frames_path
	d.modulate = mod
	return d


func _register(def) -> void:
	_by_display_name[def.display_name] = def
	all_characters.append(def)


func get_by_display_name(display_name: String):
	return _by_display_name.get(display_name, null)

extends Node

const CharacterDef = preload("res://scripts/character_def.gd")
const _simonka_frames: SpriteFrames = preload("res://resources/simonka_sprite_frames.tres")
const _veli_frames: SpriteFrames = preload("res://resources/veli_sprite_frames.tres")
const _bobe_frames: SpriteFrames = preload("res://resources/bobe_sprite_frames.tres")
const _ipman_frames: SpriteFrames = preload("res://resources/ipman_sprite_frames.tres")
const _sasho_frames: SpriteFrames = preload("res://resources/sasho_sprite_frames.tres")
const _siyana_frames: SpriteFrames = preload("res://resources/siyana_sprite_frames.tres")
const _itso_frames: SpriteFrames = preload("res://resources/itso_sprite_frames.tres")
const _ipman_proj_tex: Texture = preload("res://assets/ipman/money-projectile.png")
const _siyana_proj_tex: Texture = preload("res://assets/siyana/baby-projectile.png")

var _by_display_name: Dictionary = {}
var all_characters: Array = []

var JUMP_VELOCITY = -3200 if OS.get_name() == "X11" else -1680

func _init() -> void:
	var ipman = _make_def("ipman", "IpMan", _ipman_frames, Color(1, 1, 1, 1))
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
	ipman.flypunch_speed_scale = 1.5
	ipman.proj_damage = 10
	ipman.proj_speed = 13
	ipman.proj_hit_radius = 75
	ipman.proj_y_tolerance = 220
	ipman.proj_lifetime_ticks = 300
	ipman.proj_pool = 6
	ipman.proj_texture = _ipman_proj_tex
	ipman.proj_scale = 3.0
	ipman.proj_spawn_x_offset = 70
	ipman.proj_spawn_y_offset = 200
	ipman.proj_fires_airborne = true
	_register(ipman)

	var simonka = _make_def("simonka", "Simonka", _simonka_frames, Color(1, 1, 1, 1))
	simonka.punch_arm_extension = 140.0  # punch animation extends 20px further than Veli's
	simonka.speed = 380.0
	simonka.jump_velocity = JUMP_VELOCITY * 1.4
	simonka.punch_damage = 12
	simonka.kick_damage = 8
	simonka.block_damage_modifier = 0.12
	simonka.max_health = 100
	simonka.sprite_scale = 0.9
	_register(simonka)

	var veli = _make_def("veli", "Veli", _veli_frames, Color(1, 1, 1, 1))
	veli.speed = 320.0
	veli.jump_velocity = JUMP_VELOCITY * 0.5
	veli.punch_damage = 0
	veli.punch_pulls_opponent = true
	veli.kick_damage = 20
	veli.kick_knockback_multiplier = 3.667
	veli.block_damage_modifier = 0.18
	veli.max_health = 120
	veli.fall_gravity_scale = 0.15
	veli.invulnerable_when_airborne = true
	veli.partial_loop_jump = true
	_register(veli)

	var bobe = _make_def("bobe", "Bobe", _bobe_frames, Color(1, 1, 1, 1))
	bobe.speed = 330.0
	bobe.jump_velocity = JUMP_VELOCITY
	bobe.punch_damage = 15
	bobe.kick_damage = 10
	bobe.block_damage_modifier = 0.18
	bobe.max_health = 115
	bobe.kick_heals_self = 5
	_register(bobe)

	var sasho = _make_def("sasho", "Sasho", _sasho_frames, Color(1, 1, 1, 1))
	sasho.speed = 340.0
	sasho.jump_velocity = JUMP_VELOCITY
	sasho.punch_damage = 14
	sasho.kick_damage = 11
	sasho.block_damage_modifier = 0.15
	sasho.max_health = 110
	sasho.punch_makes_invisible = true
	_register(sasho)

	var siyana = _make_def("siyana", "Siyana", _siyana_frames, Color(1, 1, 1, 1))
	siyana.speed = 350.0
	siyana.jump_velocity = JUMP_VELOCITY
	siyana.punch_damage = 13
	siyana.kick_damage = 10
	siyana.block_damage_modifier = 0.15
	siyana.max_health = 105
	siyana.fires_projectile = true
	siyana.proj_damage = 25
	siyana.proj_trigger = "kick"
	siyana.proj_speed = 4
	siyana.proj_hit_radius = 60
	siyana.proj_y_tolerance = 100
	siyana.proj_lifetime_ticks = 240
	siyana.proj_pool = 3
	siyana.proj_texture = _siyana_proj_tex
	siyana.proj_scale = 1.0
	siyana.proj_spawn_x_offset = 80
	siyana.proj_spawn_y_offset = 0
	siyana.kick_speed_scale = 0.40
	siyana.proj_anim_hframes = 2
	siyana.proj_anim_vframes = 2
	siyana.proj_anim_fps = 8
	_register(siyana)

	var itso = _make_def("itso", "Itso", _itso_frames, Color(1, 1, 1, 1))
	itso.speed = 340.0
	itso.jump_velocity = JUMP_VELOCITY
	itso.punch_damage = 14
	itso.kick_damage = 11
	itso.block_damage_modifier = 0.15
	itso.max_health = 110
	itso.kick_lunge_scale = 6.0
	_register(itso)


func _make_def(id: String, display_name: String, frames: SpriteFrames, mod: Color):
	var d := CharacterDef.new()
	d.id = id
	d.display_name = display_name
	d.sprite_frames = frames
	d.modulate = mod
	return d


func _register(def) -> void:
	_by_display_name[def.display_name] = def
	all_characters.append(def)


func get_by_display_name(display_name: String):
	return _by_display_name.get(display_name, null)

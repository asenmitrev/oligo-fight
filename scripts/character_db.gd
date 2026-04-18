extends Node

const CharacterDef = preload("res://scripts/character_def.gd")
const _simonka_frames: SpriteFrames = preload("res://resources/simonka_sprite_frames.tres")
const _georgi_frames: SpriteFrames = preload("res://resources/georgi_sprite_frames.tres")
const _bobe_frames: SpriteFrames = preload("res://resources/bobe_sprite_frames.tres")
const _kraska_frames: SpriteFrames = preload("res://resources/kraska_sprite_frames.tres")

var _by_display_name: Dictionary = {}
var all_characters: Array = []

var JUMP_VELOCITY = -3200 if OS.get_name() == "X11" else -1680

func _init() -> void:
	var kraska = _make_def("kraska", "Kraska", _kraska_frames, Color(1, 1, 1, 1))
	kraska.punch_arm_extension = 225.0  # punch animation extends 20px further than Georgi's
	kraska.speed = 350.0
	kraska.jump_velocity = JUMP_VELOCITY
	kraska.punch_damage = 35
	kraska.kick_damage = 9
	kraska.block_damage_modifier = 0.15
	kraska.max_health = 110
	kraska.body_punch_enabled = true
	kraska.kick_speed_scale = 1.3
	_register(kraska)

	var simonka = _make_def("simonka", "Simonka", _simonka_frames, Color(1, 1, 1, 1))
	simonka.punch_arm_extension = 140.0  # punch animation extends 20px further than Georgi's
	simonka.speed = 380.0
	simonka.jump_velocity = JUMP_VELOCITY * 1.4
	simonka.punch_damage = 12
	simonka.kick_damage = 8
	simonka.block_damage_modifier = 0.12
	simonka.max_health = 100
	simonka.sprite_scale = 0.9
	_register(simonka)

	var georgi = _make_def("georgi", "Georgi", _georgi_frames, Color(1, 1, 1, 1))
	georgi.speed = 320.0
	georgi.jump_velocity = JUMP_VELOCITY
	georgi.punch_damage = 15
	georgi.kick_damage = 10
	georgi.block_damage_modifier = 0.18
	georgi.max_health = 120
	_register(georgi)

	var bobe = _make_def("bobe", "Bobe", _bobe_frames, Color(1, 1, 1, 1))
	bobe.speed = 330.0
	bobe.jump_velocity = JUMP_VELOCITY
	bobe.punch_damage = 15
	bobe.kick_damage = 10
	bobe.block_damage_modifier = 0.18
	bobe.max_health = 115
	bobe.kick_heals_self = 5
	_register(bobe)


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

extends Node

const CharacterDef = preload("res://scripts/character_def.gd")
const _simonka_frames: SpriteFrames = preload("res://resources/simonka_sprite_frames.tres")
const _georgi_frames: SpriteFrames = preload("res://resources/georgi_sprite_frames.tres")
const _boekov_frames: SpriteFrames = preload("res://resources/boekov_sprite_frames.tres")
const _boekov_preview_frames: SpriteFrames = preload("res://resources/boekov_preview_sprite_frames.tres")
const _kraska_frames: SpriteFrames = preload("res://resources/kraska_sprite_frames.tres")

var _by_display_name: Dictionary = {}
var all_characters: Array = []


func _init() -> void:
	var kraska = _make_def("kraska", "Kraska", _kraska_frames, Color(1, 1, 1, 1))
	kraska.speed = 350.0
	kraska.jump_velocity = -1680.0
	kraska.punch_damage = 16
	kraska.kick_damage = 9
	kraska.block_damage_modifier = 0.15
	kraska.max_health = 110
	kraska.body_punch_enabled = true
	_register(kraska)

	var simonka = _make_def("simonka", "Simonka", _simonka_frames, Color(1, 1, 1, 1))
	simonka.punch_arm_extension = 140.0  # punch animation extends 20px further than Georgi's
	simonka.speed = 380.0
	simonka.jump_velocity = -1750.0
	simonka.punch_damage = 15
	simonka.kick_damage = 8
	simonka.block_damage_modifier = 0.12
	simonka.max_health = 100
	simonka.sprite_scale = 0.9
	_register(simonka)

	var georgi = _make_def("georgi", "Georgi", _georgi_frames, Color(1, 1, 1, 1))
	georgi.speed = 320.0
	georgi.jump_velocity = -1600.0
	georgi.punch_damage = 18
	georgi.kick_damage = 10
	georgi.block_damage_modifier = 0.18
	georgi.max_health = 120
	_register(georgi)

	var boekov = _make_def("boekov", "Georgiy", _boekov_frames, Color(1, 1, 1, 1))
	boekov.sprite_offset = Vector2(0, 4)  # sprites sit ~7px higher than other chars
	boekov.speed = 320.0
	boekov.jump_velocity = -1600.0
	boekov.punch_damage = 18
	boekov.kick_damage = 10
	boekov.block_damage_modifier = 0.18
	boekov.max_health = 120
	boekov.sprite_scale = 1.05
	boekov.launch_punch = true
	boekov.combos_enabled = false
	boekov.preview_frames = _boekov_preview_frames
	_register(boekov)


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

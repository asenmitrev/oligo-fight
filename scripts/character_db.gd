extends Node

const CharacterDef = preload("res://scripts/character_def.gd")
const _simonka_frames: SpriteFrames = preload("res://resources/simonka_sprite_frames.tres")
const _georgi_frames: SpriteFrames = preload("res://resources/georgi_sprite_frames.tres")

var _by_display_name: Dictionary = {}
var all_characters: Array = []


func _init() -> void:
	var simonka = _make_def("simonka", "Simonka", _simonka_frames, Color(1, 1, 1, 1))
	simonka.punch_arm_extension = 140.0  # punch animation extends 20px further than Georgi's
	simonka.speed = 380.0
	simonka.jump_velocity = -1750.0
	simonka.punch_damage = 15
	simonka.kick_damage = 8
	simonka.block_damage_modifier = 0.12
	simonka.max_health = 100
	_register(simonka)

	var georgi = _make_def("georgi", "Georgi", _georgi_frames, Color(1, 1, 1, 1))
	georgi.speed = 320.0
	georgi.jump_velocity = -1600.0
	georgi.punch_damage = 18
	georgi.kick_damage = 10
	georgi.block_damage_modifier = 0.18
	georgi.max_health = 120
	_register(georgi)


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

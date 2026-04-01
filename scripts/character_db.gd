extends Node

const CharacterDef = preload("res://scripts/character_def.gd")
const _simonka_frames: SpriteFrames = preload("res://resources/simonka_sprite_frames.tres")
const _georgi_frames: SpriteFrames = preload("res://resources/georgi_sprite_frames.tres")

var _by_display_name: Dictionary = {}
var all_characters: Array = []


func _init() -> void:
	_register(_make_def("simonka", "Simonka", _simonka_frames, Color(1, 1, 1, 1)))
	_register(_make_def("georgi", "Georgi", _georgi_frames, Color(1, 1, 1, 1)))


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

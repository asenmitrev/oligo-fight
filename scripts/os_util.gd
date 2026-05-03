# os_util.gd - OS detection utility for platform-specific behavior
extends Node

var _is_arch_x11: bool = false


func _ready() -> void:
	_is_arch_x11 = _detect_arch_x11()
	print("[OsUtil] OS=%s, arch_x11=%s, directions_reversed=%s" % [OS.get_name(), _is_arch_x11, is_direction_reversed()])


func _detect_arch_x11() -> bool:
	if OS.get_name() != "X11":
		return false

	var f = File.new()
	if f.file_exists("/etc/os-release"):
		if f.open("/etc/os-release", f.READ) == OK:
			while not f.eof_reached():
				var line = f.get_line()
				if line.begins_with("ID="):
					var id = line.replace("ID=", "").replace('"', "")
					f.close()
					return id == "arch"
			f.close()

	return false


func is_direction_reversed() -> bool:
	return _is_arch_x11


# Flip a direction delta (e.g. +1 -> -1, -1 -> +1) when on Arch X11
func reverse_direction(direction: int) -> int:
	if _is_arch_x11:
		return -direction
	return direction

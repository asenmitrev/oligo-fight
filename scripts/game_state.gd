extends Node

var p1_character: String = "Simonka"
var p2_character: String = "Veli"
var p2_is_mirror: bool = false
# Index into Fight scene's fight backgrounds; set when a new fight starts from character select.
const FIGHT_BACKGROUND_COUNT := 4
var fight_background_index: int = 0

const P1_COLOR := Color(0.2, 0.6, 1.0, 1.0) # Blue
const P2_COLOR := Color(0.9, 0.15, 0.15, 1.0) # Red

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	yield(get_tree(), "idle_frame")
	# On Linux without a window manager (e.g. RetroPie via startx),
	# EWMH fullscreen hints are ignored. Force fullscreen manually.
	if OS.get_name() == "X11":
		OS.window_borderless = true
		OS.window_position = Vector2(0, 0)
		OS.window_size = OS.get_screen_size()
	else:
		OS.window_fullscreen = true

func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("start") and Input.is_action_pressed("pause")) or \
	   (event.is_action_pressed("pause") and Input.is_action_pressed("start")):
		get_tree().quit()

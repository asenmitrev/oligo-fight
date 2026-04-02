extends Node

var p1_character: String = "Simonka"
var p2_character: String = "Georgi"
var p2_is_mirror: bool = false
# Index into Fight scene's fight backgrounds; set when a new fight starts from character select.
const FIGHT_BACKGROUND_COUNT := 4
var fight_background_index: int = 0

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS

func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("start") and Input.is_action_pressed("pause")) or \
	   (event.is_action_pressed("pause") and Input.is_action_pressed("start")):
		get_tree().quit()

extends Node2D

@onready var win_screen: ColorRect = $HUD/WinScreen
@onready var win_label: Label = $HUD/WinScreen/WinLabel

func _ready() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		player.defeated.connect(_on_player_defeated)

func _on_player_defeated() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_defeated:
			win_label.text = player.display_name + " Wins!"
			break
	win_screen.visible = true

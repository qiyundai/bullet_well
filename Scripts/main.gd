extends Control

@export var game_scene: PackedScene

@onready var start_button := $MarginContainer/Button


func _ready() -> void:
	start_button.pressed.connect(_start_game)
	start_button.grab_focus()

	
func _start_game() -> void:
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

extends Control

@onready var start_button := $MarginContainer/Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_button.pressed.connect(_start_game)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _start_game() -> void:
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

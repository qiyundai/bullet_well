extends Control

@onready var retry_button := $MarginContainer/Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	retry_button.pressed.connect(_reset_game_scene)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _reset_game_scene() -> void:
	get_tree().reload_current_scene()

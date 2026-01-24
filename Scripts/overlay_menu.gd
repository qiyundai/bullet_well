extends Control

@onready var retry_button := $MarginContainer/VBoxContainer/RetryButton

## Optional: Connect these to Label nodes you add in the editor.
## Set the node paths in the Inspector, or update these paths after adding labels.
@export var last_score_label: Label
@export var high_score_label: Label


func _ready() -> void:
	retry_button.pressed.connect(_reset_game_scene)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_update_score_display()
		retry_button.grab_focus()


func _update_score_display() -> void:
	if last_score_label:
		last_score_label.text = "Score: %d" % ScoreManager.last_score
	
	if high_score_label:
		high_score_label.text = "Best: %d" % ScoreManager.high_score

	
func _reset_game_scene() -> void:
	get_tree().reload_current_scene()

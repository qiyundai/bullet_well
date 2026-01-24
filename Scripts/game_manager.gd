extends Node

@onready var ui := $"../UICanvas/OverlayMenu"
@onready var player: CharacterBody2D = $"../Player"

@export var current_score_label: Label

func _ready() -> void:
	# Start tracking score from player's initial position
	if player:
		ScoreManager.start_tracking(player.global_position.y)

func _process(_delta) -> void:
	if current_score_label:
		current_score_label.text = "%d" % ScoreManager.current_score
	
func game_over() -> void:
	ScoreManager.end_run()
	ui._update_score_display()
	ui.visible = true

extends Camera2D
@export var target: Node2D
@export var y_offset := -120.0
@export var down_slack := 260.0  # pixels camera may move down from best

var best_y := INF

func _process(_dt):
	if target == null:
		return

	var desired_y := target.global_position.y + y_offset

	# Track highest point (smallest y)
	best_y = min(best_y, desired_y)

	# Clamp camera so it never goes below best_y + down_slack
	global_position.y = clamp(desired_y, best_y, best_y + down_slack)

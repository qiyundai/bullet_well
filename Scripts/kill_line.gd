extends Area2D

## Kill line that follows the camera vertically and kills anything that falls through.
## Should be a child of a Node2D positioned at screen center X.

@export var y_offset: float = 660.0  # Offset below camera center

var _camera: Camera2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Find the camera (deferred to ensure scene is ready)
	call_deferred("_find_camera")


func _find_camera() -> void:
	# Look for camera in player group first
	var players = get_tree().get_nodes_in_group("player")
	for node in players:
		if node is CharacterBody2D:
			var cam = node.get_node_or_null("Camera2D")
			if cam:
				_camera = cam
				return
	
	# Fallback: find any Camera2D
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0 and cameras[0] is Camera2D:
		_camera = cameras[0]


func _process(_delta: float) -> void:
	_follow_camera()


func _follow_camera() -> void:
	if _camera == null:
		_find_camera()
		return
	
	# Move parent node to follow camera Y position
	var parent_node = get_parent()
	if parent_node:
		parent_node.global_position.y = _camera.global_position.y + y_offset


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("game_manager", "game_over")
	
	# Also kill mobs that fall through
	if body.is_in_group("mobs"):
		if body.has_method("_on_kill_line_hit"):
			body._on_kill_line_hit()
		else:
			body.queue_free()

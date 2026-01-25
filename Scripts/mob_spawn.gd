extends Area2D

## Spawns wall climber mobs that climb the walls and leap at the player.
## Uses exponential decay difficulty scaling based on player score.
## Follows the camera vertically to stay just above the kill line.
## Requires SpawnPointL and SpawnPointR Marker2D children for spawn positions.

@export var crawler_scene: PackedScene
@export var min_spawn_interval: float = 3.0  # seconds between spawns at max difficulty
@export var max_spawn_interval: float = 8.0  # seconds between spawns at start
@export var min_climb_speed: float = 150.0   # climb speed at start
@export var max_climb_speed: float = 400.0   # climb speed at max difficulty
@export var score_threshold: int = 50       # mobs only spawn after this score
@export var difficulty_scale_rate: float = 0.005  # exponential decay rate
@export var y_offset: float = 609.0  # Offset below camera center (above kill line)

# Camera reference for following
var _camera: Camera2D = null

# Spawn point markers (set in _ready)
var _spawn_point_left: Marker2D = null
var _spawn_point_right: Marker2D = null

var _spawn_timer: float = 0.0
var _current_spawn_interval: float = 8.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_current_spawn_interval = max_spawn_interval
	
	# Find spawn point markers (children of this Area2D)
	_spawn_point_left = get_node_or_null("SpawnPointL")
	_spawn_point_right = get_node_or_null("SpawnPointR")
	
	if _spawn_point_left == null or _spawn_point_right == null:
		push_warning("MobSpawn: Missing SpawnPointL or SpawnPointR markers!")
	
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


func _process(delta: float) -> void:
	# Follow camera
	_follow_camera()
	
	# Don't spawn until score threshold is reached
	if ScoreManager.current_score < score_threshold:
		return
	
	# Update difficulty scaling
	_update_difficulty()
	
	# Spawn timer
	_spawn_timer += delta
	if _spawn_timer >= _current_spawn_interval:
		_spawn_timer = 0.0
		_spawn_wall_climber()


func _follow_camera() -> void:
	if _camera == null:
		_find_camera()
		return
	
	# Move parent node to follow camera Y position
	var parent_node = get_parent()
	if parent_node:
		parent_node.global_position.y = _camera.global_position.y + y_offset


func _update_difficulty() -> void:
	# Exponential decay formula: value = min + (max - min) * e^(-rate * score)
	# As score increases, spawn interval decreases and climb speed increases
	var score = ScoreManager.current_score - score_threshold
	var decay_factor = exp(-difficulty_scale_rate * score)
	
	# Spawn interval: starts high, asymptotically approaches min
	_current_spawn_interval = min_spawn_interval + (max_spawn_interval - min_spawn_interval) * decay_factor


func _get_current_climb_speed() -> float:
	# Exponential decay formula for climb speed (inverted - starts low, goes high)
	var score = ScoreManager.current_score - score_threshold
	var decay_factor = exp(-difficulty_scale_rate * score)
	
	# Climb speed: starts low, asymptotically approaches max
	return max_climb_speed - (max_climb_speed - min_climb_speed) * decay_factor


func _spawn_wall_climber() -> void:
	if crawler_scene == null:
		push_warning("MobSpawn: No crawler_scene assigned!")
		return
	
	if _spawn_point_left == null or _spawn_point_right == null:
		push_warning("MobSpawn: Spawn point markers not found!")
		return
	
	var crawler = crawler_scene.instantiate()
	
	# Randomly pick left or right wall using the markers
	var side: int  # 0 = LEFT, 1 = RIGHT
	if _rng.randf() < 0.5:
		side = 0  # LEFT
		crawler.global_position = _spawn_point_left.global_position
	else:
		side = 1  # RIGHT
		crawler.global_position = _spawn_point_right.global_position
	
	# Configure the crawler
	crawler.setup_as_wall_climber(side)
	crawler.set_climb_speed(_get_current_climb_speed())
	
	# Add to scene
	get_tree().current_scene.add_child(crawler)

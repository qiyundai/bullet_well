extends Node

## Autoload singleton for persistent score tracking.
## Tracks current run score, last attempt score, and all-time high score.
## Saves to user:// directory so data persists between game sessions.

# Score tracking
var current_score: int = 0
var last_score: int = 0
var high_score: int = 0

# For distance-based scoring
var _start_y: float = 0.0
var _tracking_enabled: bool = false

const SAVE_PATH = "user://scores.cfg"
const PIXELS_PER_POINT = 100.0  # How many pixels of descent = 1 point

signal score_changed(new_score: int)

func _ready() -> void:
	load_scores()


func _process(_delta: float) -> void:
	if not _tracking_enabled:
		return
	
	# Find player and update score based on distance fallen
	var players = get_tree().get_nodes_in_group("player")
	for node in players:
		if node is CharacterBody2D:
			_update_score_from_position(node.global_position.y)
			break


func start_tracking(start_y: float) -> void:
	"""Call this when the game starts to begin score tracking."""
	_start_y = start_y
	_tracking_enabled = true
	current_score = 0
	score_changed.emit(current_score)


func stop_tracking() -> void:
	"""Call this when the game ends to stop score tracking."""
	_tracking_enabled = false


func _update_score_from_position(current_y: float) -> void:
	# Player "falls" upward in this game (Y decreases as they descend the well)
	# Score = how far above starting position (inverted Y)
	var distance_fallen = _start_y - current_y
	if distance_fallen > 0:
		var new_score = int(distance_fallen / PIXELS_PER_POINT)
		if new_score > current_score:
			current_score = new_score
			score_changed.emit(current_score)


func add_score(amount: int) -> void:
	"""Manually add points to the current score."""
	current_score += amount
	score_changed.emit(current_score)


func end_run() -> void:
	"""Call this when the player dies. Saves scores and resets for next run."""
	stop_tracking()
	last_score = current_score
	if current_score > high_score:
		high_score = current_score
	save_scores()
	current_score = 0


func save_scores() -> void:
	var config = ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.set_value("scores", "last_score", last_score)
	var err = config.save(SAVE_PATH)
	if err != OK:
		push_warning("ScoreManager: Failed to save scores, error code: %d" % err)


func load_scores() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		high_score = config.get_value("scores", "high_score", 0)
		last_score = config.get_value("scores", "last_score", 0)
	# If file doesn't exist, that's fine - we start with 0s


func reset_all_scores() -> void:
	"""Debug/settings function to clear all saved scores."""
	current_score = 0
	last_score = 0
	high_score = 0
	save_scores()

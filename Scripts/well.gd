extends Node2D

@export var camera: Node2D
@export var keep_ahead: float = 1.0

# --- Platforms ---
@export var platform_scene: PackedScene
@export var platforms_parent: NodePath

# Wall margin (extra padding from detected wall edges)
@export var wall_margin: float = 8.0

# Coverage band around camera (pixels)
@export var spawn_ahead_px: float = 1400.0
@export var spawn_behind_px: float = 900.0
@export var despawn_below_px: float = 1400.0

# Platform density tuning
@export var gap_min: float = 60.0               # minimum vertical gap between platforms
@export var gap_max_factor: float = 0.75        # max gap as fraction of max jump height
@export var horizontal_reach_safety: float = 0.7 # safety margin for horizontal reach
@export var extra_platform_chance: float = 0.2  # chance to spawn additional platform per row

# --- Runtime state (walls) ---
var chunks: Array[Node2D] = []
var chunk_height: float = 0.0

# --- Runtime state (bounds - auto-detected) ---
var _inner_left_x: float = 0.0
var _inner_right_x: float = 0.0

# --- Runtime state (player reference) ---
var _player: CharacterBody2D = null

# --- Runtime state (platforms) ---
var _rng := RandomNumberGenerator.new()
var _platforms: Array[Node2D] = []
var _next_spawn_y: float = 0.0
var _plat_half_width: float = 0.0

# Frontier: recent platforms we can jump FROM (stores positions)
var _frontier: Array[Vector2] = []
const FRONTIER_DEPTH: float = 400.0  # keep platforms within this vertical distance

func _ready():
	_rng.randomize()
	
	# --- Find player ---
	_player = _find_player()
	if _player == null:
		push_warning("Well: Could not find player node. Platform spacing may be suboptimal.")
	
	# --- Walls setup ---
	chunks = [$Wall_A, $Wall_B, $Wall_C]
	chunks.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)
	chunk_height = abs(chunks[1].global_position.y - chunks[0].global_position.y)
	if chunk_height <= 0.0:
		push_error("Well: chunk_height could not be inferred. Make sure Wall_A/B are stacked with different Y.")
		return
	
	# --- Detect inner bounds from wall geometry ---
	_detect_inner_bounds()
	
	# --- Platform setup ---
	if platform_scene != null:
		_plat_half_width = _infer_platform_half_width(platform_scene)
		
		if camera != null:
			_next_spawn_y = camera.global_position.y + spawn_behind_px
		else:
			_next_spawn_y = global_position.y
		
		_ensure_platforms_cover_band()

func _process(_dt):
	if camera == null or chunk_height <= 0.0:
		return
	
	# --- Recycle walls ---
	var y := camera.global_position.y
	var top_chunk := chunks[chunks.size() - 1]
	var top_y := top_chunk.global_position.y
	var desired_top_y := y - (keep_ahead * chunk_height)
	
	while top_y > desired_top_y:
		_recycle_bottom_to_top()
		top_chunk = chunks[chunks.size() - 1]
		top_y = top_chunk.global_position.y
	
	# --- Platforms ---
	if platform_scene != null:
		_ensure_platforms_cover_band()
		_despawn_old_platforms()

func _recycle_bottom_to_top():
	var bottom := chunks[0]
	var top := chunks[chunks.size() - 1]
	bottom.global_position.y = top.global_position.y - chunk_height
	chunks.pop_front()
	chunks.push_back(bottom)

# =====================================================================
#  PLAYER & BOUNDS DETECTION
# =====================================================================

func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	for node in players:
		if node is CharacterBody2D:
			return node
	return null

func _detect_inner_bounds() -> void:
	# Use Wall_A to detect the inner bounds
	var wall := $Wall_A as Node2D
	if wall == null:
		push_error("Well: Wall_A not found for bounds detection.")
		return
	
	var wall_left: StaticBody2D = wall.get_node_or_null("WallBodyL")
	var wall_right: StaticBody2D = wall.get_node_or_null("WallBodyR")
	
	if wall_left == null or wall_right == null:
		push_error("Well: WallBodyL or WallBodyR not found in Wall_A.")
		return
	
	# Get collision shapes to find inner edges
	var shape_l := _get_collision_shape(wall_left)
	var shape_r := _get_collision_shape(wall_right)
	
	if shape_l == null or shape_r == null:
		push_error("Well: Could not find RectangleShape2D in wall bodies.")
		return
	
	# Calculate inner edges (global X coordinates)
	# Left wall's right edge = wall.global_x + wallBodyL.local_x + half_width
	var left_inner_edge := wall.global_position.x + wall_left.position.x + shape_l.size.x * 0.5
	# Right wall's left edge = wall.global_x + wallBodyR.local_x - half_width  
	var right_inner_edge := wall.global_position.x + wall_right.position.x - shape_r.size.x * 0.5
	
	_inner_left_x = left_inner_edge + wall_margin
	_inner_right_x = right_inner_edge - wall_margin
	
	print("Well: Detected inner bounds [%d, %d]" % [int(_inner_left_x), int(_inner_right_x)])

func _get_collision_shape(body: StaticBody2D) -> RectangleShape2D:
	for child in body.get_children():
		if child is CollisionShape2D:
			var shape := (child as CollisionShape2D).shape
			if shape is RectangleShape2D:
				return shape
	return null

# =====================================================================
#  PLAYER MOVEMENT PARAMETERS (read dynamically)
# =====================================================================

func _player_speed() -> float:
	if _player != null and "speed" in _player:
		return _player.speed
	return 300.0  # fallback

func _player_jump_velocity() -> float:
	if _player != null and "jump_velocity" in _player:
		return _player.jump_velocity
	return -420.0  # fallback

func _player_hold_force() -> float:
	if _player != null and "hold_force" in _player:
		return _player.hold_force
	return 1200.0  # fallback

func _player_hold_time_max() -> float:
	if _player != null and "hold_time_max" in _player:
		return _player.hold_time_max
	return 0.18  # fallback

func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))

# =====================================================================
#  JUMP PHYSICS CALCULATIONS
# =====================================================================

## Calculate the maximum jump height with full hold
func _max_jump_height() -> float:
	var g := _gravity()
	var v0 := -_player_jump_velocity()  # make positive (upward)
	var hold_accel := _player_hold_force() - g  # net upward accel during hold
	var t_hold := _player_hold_time_max()
	
	# Velocity after hold phase
	var v1 := v0 + hold_accel * t_hold
	if v1 < 0.0:
		v1 = 0.0  # stopped during hold phase
	
	# Height gained during hold phase
	var h_hold := v0 * t_hold + 0.5 * hold_accel * t_hold * t_hold
	
	# Height gained coasting upward after hold (until v=0)
	var h_coast := (v1 * v1) / (2.0 * g)
	
	return max(0.0, h_hold + h_coast)

## Calculate time in air to jump to a given height (0 = same level, positive = upward)
## Returns total air time (up + down to land on the target platform)
func _air_time_for_height(target_height: float) -> float:
	var g := _gravity()
	var v0 := -_player_jump_velocity()
	var hold_accel := _player_hold_force() - g
	var t_hold := _player_hold_time_max()
	
	# For simplicity, calculate air time for a full jump arc
	# This is conservative (gives more time than a minimal jump)
	
	# Full jump: time to peak + time to fall to target height
	var max_h := _max_jump_height()
	
	if target_height > max_h:
		return 0.0  # unreachable
	
	# Time to reach peak (approximate - using average velocity during hold + coast)
	var v1 := v0 + hold_accel * t_hold
	var t_coast := v1 / g if v1 > 0 else 0.0
	var t_up := t_hold + t_coast
	
	# Time to fall from peak to target height
	var fall_distance := max_h - target_height
	var t_down := sqrt(2.0 * fall_distance / g) if fall_distance > 0 else 0.0
	
	return t_up + t_down

## Calculate horizontal reach for a given vertical jump height
func _horizontal_reach_for_height(target_height: float) -> float:
	var air_time := _air_time_for_height(target_height)
	return _player_speed() * air_time * horizontal_reach_safety

# =====================================================================
#  PLATFORM GENERATION
# =====================================================================

func _platform_container() -> Node:
	if platforms_parent != NodePath():
		return get_node(platforms_parent)
	return self

func _ensure_platforms_cover_band() -> void:
	var cam_y := camera.global_position.y
	var top_y := cam_y - spawn_ahead_px
	
	while _next_spawn_y > top_y:
		_spawn_platform_smart()

func _spawn_platform_smart() -> void:
	# Prune old frontier platforms
	_prune_frontier()
	
	# Determine vertical gap
	var max_gap := _max_jump_height() * gap_max_factor
	var gap := _rng.randf_range(gap_min, max(gap_min, max_gap))
	var new_y := _next_spawn_y - gap
	
	# Calculate valid X range (within walls, accounting for platform width)
	var x_min := _inner_left_x + _plat_half_width
	var x_max := _inner_right_x - _plat_half_width
	
	if x_max <= x_min:
		_next_spawn_y = new_y
		return
	
	# Find reachable X range from frontier
	var reachable_ranges := _get_reachable_x_ranges(new_y, x_min, x_max)
	
	var primary_x: float
	if reachable_ranges.size() > 0:
		# Pick a random position within a random reachable range
		var range_idx := _rng.randi() % reachable_ranges.size()
		var r: Vector2 = reachable_ranges[range_idx]
		primary_x = _rng.randf_range(r.x, r.y)
	else:
		# No frontier or first platforms - spawn anywhere
		primary_x = _rng.randf_range(x_min, x_max)
	
	var primary_pos := Vector2(primary_x, new_y)
	_spawn_platform(primary_pos)
	_frontier.append(primary_pos)
	
	# Chance to spawn additional platform
	if _rng.randf() < extra_platform_chance:
		# For extra platform, pick any valid X (doesn't need to be reachable from frontier,
		# but the primary platform IS reachable, so player has a path)
		var secondary_x := _rng.randf_range(x_min, x_max)
		# Ensure some horizontal separation
		var min_separation := _plat_half_width * 3.0
		var tries := 5
		while tries > 0 and abs(secondary_x - primary_x) < min_separation:
			secondary_x = _rng.randf_range(x_min, x_max)
			tries -= 1
		
		if abs(secondary_x - primary_x) >= min_separation:
			var secondary_pos := Vector2(secondary_x, new_y)
			_spawn_platform(secondary_pos)
			_frontier.append(secondary_pos)
	
	_next_spawn_y = new_y

## Get array of Vector2 ranges (x_min, x_max) that are reachable from frontier platforms
func _get_reachable_x_ranges(target_y: float, bound_min: float, bound_max: float) -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	
	for plat_pos in _frontier:
		var height_diff := plat_pos.y - target_y  # positive = target is above
		
		if height_diff < 0:
			continue  # target is below this platform, skip (we spawn upward)
		
		var h_reach := _horizontal_reach_for_height(height_diff)
		if h_reach <= 0:
			continue  # unreachable height
		
		var range_min: float = max(bound_min, plat_pos.x - h_reach)
		var range_max: float = min(bound_max, plat_pos.x + h_reach)
		
		if range_max > range_min:
			ranges.append(Vector2(range_min, range_max))
	
	# Merge overlapping ranges for cleaner selection
	return _merge_ranges(ranges)

func _merge_ranges(ranges: Array[Vector2]) -> Array[Vector2]:
	if ranges.size() <= 1:
		return ranges
	
	# Sort by start position
	ranges.sort_custom(func(a, b): return a.x < b.x)
	
	var merged: Array[Vector2] = []
	var current: Vector2 = ranges[0]
	
	for i in range(1, ranges.size()):
		var r: Vector2 = ranges[i]
		if r.x <= current.y:  # overlapping
			current.y = max(current.y, r.y)
		else:
			merged.append(current)
			current = r
	merged.append(current)
	
	return merged

func _prune_frontier() -> void:
	# Remove platforms too far below the next spawn position
	var cutoff := _next_spawn_y + FRONTIER_DEPTH
	var i := _frontier.size() - 1
	while i >= 0:
		if _frontier[i].y > cutoff:
			_frontier.remove_at(i)
		i -= 1

func _spawn_platform(pos: Vector2) -> void:
	var p := platform_scene.instantiate() as Node2D
	_platform_container().add_child(p)
	p.global_position = pos
	_platforms.append(p)

func _despawn_old_platforms() -> void:
	var cam_y := camera.global_position.y
	var cutoff := cam_y + despawn_below_px
	for i in range(_platforms.size() - 1, -1, -1):
		var p := _platforms[i]
		if p == null:
			_platforms.remove_at(i)
			continue
		if p.global_position.y > cutoff:
			p.queue_free()
			_platforms.remove_at(i)

func _infer_platform_half_width(scene: PackedScene) -> float:
	var inst: Node = scene.instantiate()
	var half := 0.0
	
	var stack: Array[Node] = [inst]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is CollisionShape2D:
			var shape := (n as CollisionShape2D).shape
			if shape is RectangleShape2D:
				half = (shape as RectangleShape2D).size.x * 0.5
				break
		for c in n.get_children():
			if c is Node:
				stack.append(c)
	
	inst.queue_free()
	return max(half, 8.0)

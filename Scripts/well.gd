extends Node2D

@export var camera: Node2D # Camera2D recommended
@export var keep_ahead: float = 1.0 # wall chunks ahead (in chunks)

# --- Platforms ---
@export var platform_scene: PackedScene
@export var platforms_parent: NodePath # optional: where to put platforms (defaults to self)

# Inner bounds between walls (world X)
@export var inner_left_x: float = 64
@export var inner_right_x: float = 656
@export var wall_margin: float = 0.0 # extra padding away from walls (pixels)

# Coverage band around camera (pixels)
@export var spawn_ahead_px: float = 1400.0     # above camera
@export var spawn_behind_px: float = 900.0     # below camera (include your dip)
@export var despawn_below_px: float = 1400.0   # below camera to delete

# Jump params (match your Player exports)
@export var jump_velocity := -420.0
@export var hold_force := 1200.0
@export var hold_time_max := 0.18

# Platform density
@export var gap_min: float = 90.0
@export var gap_safety: float = 0.5 # fraction of max jump height, higher than .5 could result in unreachable platforms
@export var extra_platform_chance := 0.1
@export var min_dx_between := 90.0

# --- Walls ---
var chunks: Array[Node2D] = []
var chunk_height: float = 0.0

# --- Platform runtime ---
var _rng := RandomNumberGenerator.new()
var _platforms: Array[Node2D] = []
var _next_spawn_y: float = 0.0
var _plat_half_width: float = 0.0

func _ready():
	_rng.randomize()

	# --- Walls setup ---
	chunks = [$Wall_A, $Wall_B, $Wall_C]
	chunks.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)
	chunk_height = abs(chunks[1].global_position.y - chunks[0].global_position.y)
	if chunk_height <= 0.0:
		push_error("Well: chunk_height could not be inferred. Make sure Wall_A/B are stacked with different Y.")
		return

	# --- Platform setup ---
	if platform_scene != null:
		_plat_half_width = _infer_platform_half_width(platform_scene)
		# Start spawn line at the bottom of our coverage band
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

# ---------------- Platforms ----------------

func _platform_container() -> Node:
	if platforms_parent != NodePath():
		return get_node(platforms_parent)
	return self

func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _max_jump_height() -> float:
	var g := _gravity()
	var u0 := -jump_velocity
	var a_up := hold_force - g
	var t := hold_time_max

	var u1 := u0 + a_up * t
	if u1 < 0.0:
		u1 = 0.0

	var h_hold := u0 * t + 0.5 * a_up * t * t
	var h_coast := (u1 * u1) / (2.0 * g)
	return max(0.0, h_hold + h_coast)

func _random_gap() -> float:
	var max_gap: float = gap_min
	var jump_gap: float = _max_jump_height() * gap_safety
	if jump_gap > max_gap:
		max_gap = jump_gap
	return _rng.randf_range(gap_min, max_gap)

func _ensure_platforms_cover_band() -> void:
	var cam_y := camera.global_position.y
	var top_y := cam_y - spawn_ahead_px
	# We don’t actually need bottom_y for spawning since we spawn upward via _next_spawn_y

	while _next_spawn_y > top_y:
		_spawn_row_at(_next_spawn_y)
		_next_spawn_y -= _random_gap()

func _spawn_row_at(y: float) -> void:
	var x_min := inner_left_x + wall_margin + _plat_half_width
	var x_max := inner_right_x - wall_margin - _plat_half_width
	if x_max <= x_min:
		return

	var first_x := _rng.randf_range(x_min, x_max)
	_spawn_platform(Vector2(first_x, y))

	if _rng.randf() < extra_platform_chance:
		var second_x := _rng.randf_range(x_min, x_max)
		var tries := 8
		while tries > 0 and abs(second_x - first_x) < min_dx_between:
			second_x = _rng.randf_range(x_min, x_max)
			tries -= 1
		_spawn_platform(Vector2(second_x, y))

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

	# Depth-first scan for a RectangleShape2D
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

	# Fallback so we never clamp to zero width
	return max(half, 8.0)

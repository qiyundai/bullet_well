extends CharacterBody2D

## Wall Climber mob that spawns at mob_spawn line, climbs wall, and lunges at player.

enum WallSide { LEFT, RIGHT }
enum ClimberState { CLIMBING, AIRBORNE }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox

# --- Configuration ---
@export var base_climb_speed: float = 150.0
@export var lunge_time: float = 0.5  # How long the lunge should take to reach target
@export var spawn_immunity_time: float = 0.5  # seconds of immunity after spawn
@export var bounds_margin: float = 200.0  # How far outside screen before cleanup

# --- Runtime state ---
var wall_side: WallSide = WallSide.LEFT
var climber_state: ClimberState = ClimberState.CLIMBING
var _player: CharacterBody2D = null
var _is_dead: bool = false
var _spawn_time_sec: float = 0.0

# Difficulty-scaled climb speed
var climb_speed: float = 150.0


func _ready() -> void:
	add_to_group("mobs")
	sprite.play("crawl")
	
	_spawn_time_sec = Time.get_ticks_msec() / 1000.0
	_player = _find_player()
	
	_setup_wall_climber()
	
	# Connect hitbox for player collision
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	match climber_state:
		ClimberState.CLIMBING:
			if not _is_dead:
				_climb_wall()
		ClimberState.AIRBORNE:
			_process_airborne(delta)


# =============================================================================
# WALL CLIMBER BEHAVIOR
# =============================================================================

func _setup_wall_climber() -> void:
	# Rotate 90 degrees counter-clockwise to face upward
	rotation_degrees = -90.0
	
	# Flip sprite if on left wall (so mob faces inward)
	if wall_side == WallSide.LEFT:
		sprite.flip_v = true


func _climb_wall() -> void:
	# Move upward (negative Y in Godot)
	velocity = Vector2(0.0, -climb_speed)
	move_and_slide()
	
	# Check if at same height as player
	if _player and not _player.is_queued_for_deletion():
		var height_diff = global_position.y - _player.global_position.y
		if height_diff <= 0:  # At or above player height
			_initiate_lunge()


func _initiate_lunge() -> void:
	climber_state = ClimberState.AIRBORNE
	
	# Reset rotation for lunge
	rotation_degrees = 0.0
	sprite.flip_v = false
	
	if _player == null or _player.is_queued_for_deletion():
		# No player, just fall straight down
		velocity = Vector2.ZERO
		return
	
	# Calculate launch velocity using projectile motion physics
	# to reach player's current position in lunge_time seconds
	var target = _player.global_position
	var start = global_position
	var dx = target.x - start.x
	var dy = target.y - start.y
	var g = get_gravity().y
	
	# Projectile motion equations:
	# x = vx * t
	# y = vy * t + 0.5 * g * t^2
	# Solving for vx and vy to hit (dx, dy) at time t:
	var vx = dx / lunge_time
	var vy = (dy - 0.5 * g * lunge_time * lunge_time) / lunge_time
	
	velocity = Vector2(vx, vy)
	
	# Face the lunge direction
	if dx < 0:
		sprite.flip_h = true


func _process_airborne(delta: float) -> void:
	# Apply gravity and let physics handle the arc
	velocity += get_gravity() * delta
	move_and_slide()
	

# =============================================================================
# COLLISION & DAMAGE
# =============================================================================

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	
	if not body.is_in_group("player"):
		return
	
	# Can damage during both CLIMBING and AIRBORNE (the lunge is one continuous attack)
	_damage_player(body)


func _damage_player(player_body: Node2D) -> void:
	# Calculate hit direction (from mob to player)
	var hit_direction = (player_body.global_position - global_position).normalized()
	if hit_direction.length() < 0.001:
		hit_direction = Vector2.UP
	
	# Use player's projectile hit handler if available
	if player_body.has_method("_on_projectile_hit"):
		# Use a moderate velocity for the corpse knockback
		var knockback_velocity = hit_direction * 300.0
		player_body._on_projectile_hit(hit_direction, knockback_velocity)


func _on_projectile_hit() -> void:
	"""Called when hit by a projectile. Wall climbers are invincible once airborne."""
	if _is_dead:
		return
	
	# Wall climbers are invincible once they leave the wall
	if climber_state != ClimberState.CLIMBING:
		return
	
	die()


func _on_kill_line_hit() -> void:
	"""Called when touching the kill line."""
	if _is_dead:
		return
	
	# Spawn immunity - don't die immediately after spawning
	var now_sec = Time.get_ticks_msec() / 1000.0
	if now_sec - _spawn_time_sec < spawn_immunity_time:
		return
	
	die()
	queue_free()


func die() -> void:
	_is_dead = true
	sprite.stop()
	
	# Transition to airborne so it falls
	climber_state = ClimberState.AIRBORNE
	velocity = Vector2.ZERO  # Will fall with gravity


# =============================================================================
# UTILITY
# =============================================================================

func _find_player() -> CharacterBody2D:
	var players = get_tree().get_nodes_in_group("player")
	for node in players:
		if node is CharacterBody2D:
			return node
	return null


## Set the climb speed based on difficulty scaling
func set_climb_speed(speed: float) -> void:
	climb_speed = speed


## Configure wall side (LEFT = 0, RIGHT = 1)
func setup_as_wall_climber(side: int) -> void:
	wall_side = side as WallSide

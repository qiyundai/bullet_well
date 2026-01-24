extends CharacterBody2D

@export var speed := 300.0
@export var jump_velocity := -420.0          # initial impulse (negative = up)
@export var hold_force := 1200.0             # extra upward accel while held
@export var hold_time_max := 0.18            # max duration you can "extend" jump
@export var jump_cut_multiplier := 2.2       # higher = shorter tap jumps

@onready var player_visual: Node2D = $Visual
@onready var body: Sprite2D = $Visual/Body
@onready var foot_l: Sprite2D = $Visual/Foot_L
@onready var foot_r: Sprite2D = $Visual/Foot_R
@onready var camera: Camera2D = $Camera2D
@onready var kill_line: Node2D = $Camera2D/KillLine

# --- Tuning knobs ---
@export var bob_amplitude := 2.5        # pixels
@export var bob_frequency := 1.5        # cycles per second

@export var foot_radius := Vector2(3.0, 2.0)  # ellipse radii (x,y) in pixels
@export var foot_speed := 10.0                # radians/sec when moving
@export var foot_phase_offset := PI           # offset between feet (PI = opposite)

@export var corpse_scene: PackedScene
@export var audio_player: Node 

var _time := 0.0
var _foot_theta := 0.0
var _facing_left := false
var _foot_strength := 0.0  # 0..1, how “active” the orbit is
var _hold_time := 0.0
var _jumping := false
var _is_dead := false

var _body_base_pos := Vector2.ZERO
var _foot_l_base_pos := Vector2.ZERO
var _foot_r_base_pos := Vector2.ZERO

func _ready() -> void:
	_body_base_pos = body.position
	_foot_l_base_pos = foot_l.position
	_foot_r_base_pos = foot_r.position

func _physics_process(delta: float) -> void:
	_time += delta

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
		_set_facing(direction < 0.0)
		# Flip sprite based on movement direction
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		
	_jump(delta)
	move_and_slide()
	
	_update_idle_bob()
	_update_feet_orbit(delta, direction)

func _jump(delta: float) -> void:
	# --- Jump press ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		_jumping = true
		_hold_time = 0.0
		audio_player._play_jump()

	# --- Jump hold (extend) ---
	if _jumping and Input.is_action_pressed("ui_accept") and _hold_time < hold_time_max:
		# Add upward acceleration while rising.
		# Only while moving upward so it doesn't "float" on the way down.
		if velocity.y < 0.0:
			velocity.y -= hold_force * delta
		_hold_time += delta

	# --- Jump release (cut) ---
	if _jumping and Input.is_action_just_released("ui_accept"):
		# If still going up, cut it so short taps feel snappy.
		if velocity.y < 0.0:
			velocity.y *= 1.0 / jump_cut_multiplier
		_jumping = false

	# Landing resets
	if is_on_floor() and velocity.y >= 0.0:
		_jumping = false

func _set_facing(left: bool) -> void:
	if left == _facing_left:
		return
	_facing_left = left

	player_visual.scale.x = -1 if left else 1

func _update_idle_bob() -> void:
	var bob := sin(_time * TAU * bob_frequency) * bob_amplitude
	body.position = _body_base_pos + Vector2(0.0, bob)

func _update_feet_orbit(delta: float, direction: float) -> void:
	# Only "walk" when there's meaningful horizontal intent AND you're on the ground
	var moving = abs(direction) > 0.01 and is_on_floor()

	# Smoothly ramp orbit on/off (no reverse spin)
	var target_strength := 1.0 if moving else 0.0
	_foot_strength = move_toward(_foot_strength, target_strength, 8.0 * delta)

	if moving:
		_foot_theta += foot_speed * delta

		# Keep theta bounded so it never grows huge (prevents “crazier over time” issues)
		_foot_theta = wrapf(_foot_theta, 0.0, TAU)

	# Compute orbit offsets (elliptical circle), scaled by strength
	var o1 := Vector2(cos(_foot_theta) * foot_radius.x, sin(_foot_theta) * foot_radius.y) * _foot_strength
	var o2 := Vector2(cos(_foot_theta + foot_phase_offset) * foot_radius.x, sin(_foot_theta + foot_phase_offset) * foot_radius.y) * _foot_strength

	foot_l.position = _foot_l_base_pos + o1
	foot_r.position = _foot_r_base_pos + o2
	
func _freeze_camera() -> void:
	# Detach camera so it survives player deletion
	var root := get_tree().current_scene
	camera.reparent(root, true)   # keep_global_transform = true
	camera.make_current()
	
func _remove_player_nodes() -> void:
	var player_nodes := get_tree().get_nodes_in_group('player')
	
	for n in player_nodes:
		n.queue_free()

func _on_projectile_hit(forward: Vector2, projectile_velocity: Vector2) -> void:
	if _is_dead:
		return
		
	_is_dead = true

	# Disable player gameplay
	set_physics_process(false)
	set_process(false)

	# Spawn corpse
	var corpse := corpse_scene.instantiate() as RigidBody2D
	corpse.global_position = global_position
	corpse.global_rotation = global_rotation

	get_tree().current_scene.call_deferred("add_child", corpse)

	# Falls in direction of projectile forward vector with half of its velocity
	var kick := forward.normalized() * (projectile_velocity.length() * 0.5)
	corpse.linear_velocity = kick

	# Optional: little spin for drama
	corpse.angular_velocity = randf_range(-8.0, 8.0)

	call_deferred("_freeze_camera")

	# call game_over
	get_tree().call_group("game_manager", "game_over")
	
	audio_player._play_hurt()
	
	_remove_player_nodes()
	
func _on_fall_through_kill_line() -> void:
	if _is_dead:
		return
	
	_is_dead = true
	
	call_deferred("_freeze_camera")
	_remove_player_nodes()
	
	pass

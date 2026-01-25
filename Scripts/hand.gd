extends RigidBody2D

@export var projectile_scene: PackedScene
@export var base_shoot_interval := 2.0
@export var min_shoot_interval := 0.25
@export var decay_rate := 0.0195
@export var projectile_speed := 700.0
@export var spawn_offset := 8.0
@export var recoil_strength := 500.0

@export var audio_player: Node

@onready var marker: Marker2D = $Gun/Muzzle
@onready var timer: Timer = $GunTimer

var shoot_interval 

func _ready():
	timer.timeout.connect(_shoot)
	_apply_difficulty_scaling()
	
func _process(_delta) -> void:
	_apply_difficulty_scaling()

func _shoot():
	var p := projectile_scene.instantiate() as CharacterBody2D

	# Direction = marker's +X axis in world space
	var dir := marker.global_transform.x.normalized()
	var recoil_dir := marker.global_transform.y.normalized()

	# Spawn position (slightly in front so it doesn't clip into shooter)
	p.global_position = marker.global_position + dir * spawn_offset

	# Give it velocity
	p.velocity = dir * projectile_speed

	# Optional: inherit shooter velocity so firing while moving feels natural
	p.velocity += linear_velocity
	
	# Recoil - kick back opposite to firing direction
	apply_central_impulse(-recoil_dir * recoil_strength)

	# Add to the current scene (NOT under the rigidbody)
	get_tree().current_scene.add_child(p)
	
	audio_player._play_gun_shoot()
	

func _apply_difficulty_scaling() -> void:
	# Exponential decay: approaches min_shoot_interval asymptotically
	# Reaches ~0.5s around score 100, never goes below 0.25s
	var score := ScoreManager.current_score
	shoot_interval = min_shoot_interval + (base_shoot_interval - min_shoot_interval) * exp(-decay_rate * score)
	timer.wait_time = shoot_interval
		

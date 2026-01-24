extends RigidBody2D

@export var projectile_scene: PackedScene
@export var base_shoot_interval := 2.0
@export var projectile_speed := 700.0
@export var spawn_offset := 8.0

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

	# Spawn position (slightly in front so it doesn't clip into shooter)
	p.global_position = marker.global_position + dir * spawn_offset

	# Give it velocity
	p.velocity = dir * projectile_speed

	# Optional: inherit shooter velocity so firing while moving feels natural
	p.velocity += self.linear_velocity

	# Add to the current scene (NOT under the rigidbody)
	get_tree().current_scene.add_child(p)
	
	audio_player._play_gun_shoot()
	

func _apply_difficulty_scaling() -> void:
	# Every 10 points of score shortens shoot_interval by 0.1s
	var bonus := ScoreManager.current_score / 50.0
	shoot_interval = base_shoot_interval - bonus

	if shoot_interval <= 0.0:
		return
		
	timer.wait_time = shoot_interval
		

extends RigidBody2D

@export var projectile_scene: PackedScene
@export var shoot_interval := 1.0
@export var projectile_speed := 700.0
@export var spawn_offset := 8.0

@onready var marker: Marker2D = $Gun/Muzzle
@onready var timer: Timer = $GunTimer

func _ready():
	timer.timeout.connect(_shoot)

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

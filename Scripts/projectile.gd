extends CharacterBody2D

@export var max_bounces := 5 # or set a limit
@export var restitution := 1.0
@export var push_out := 0.5

var bounces := 0

func _physics_process(delta: float) -> void:
	var motion := velocity * delta
	var collision := move_and_collide(motion)
	
	if collision:
		var n := collision.get_normal()
		var collider := collision.get_collider()

		if collider.is_in_group("abyss"):
			queue_free()
			return

		bounces += 1
		if bounces >= max_bounces:
			queue_free()
		# Otherwise, bounce (walls, ceiling, etc.)
		velocity = velocity.bounce(n) * restitution
		global_position += n * push_out

extends CharacterBody2D

@export var base_max_bounces := 5.0
@export var base_max_life_window := 20.0 # seconds
@export var restitution := 1.0
@export var push_out := 0.5
@export var forgive_window := 0.3 # seconds

@onready var hitbox := $CollisionShape2D/Hitbox

var max_bounces: float
var max_life_window: float
var bounces := 0
var _spawn_time_sec := 0.0

func _ready() -> void:
	_spawn_time_sec = Time.get_ticks_msec() / 1000.0
	_apply_difficulty_scaling()


func _apply_difficulty_scaling() -> void:
	# Every 10 points of score adds +1 to bounces and lifetime
	var bonus := ScoreManager.current_score / 10.0
	max_bounces = base_max_bounces + bonus
	max_life_window = base_max_life_window + bonus

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
			return

		velocity = velocity.bounce(n) * restitution
		global_position += n * push_out
		
	var now_sec := Time.get_ticks_msec() / 1000.0
	if now_sec - _spawn_time_sec > max_life_window:
		queue_free()
		return

func _on_hitbox_body_entered(body: Node2D) -> void:
	# --- forgiveness window: can't kill player right after spawn ---
	var now_sec := Time.get_ticks_msec() / 1000.0
	if now_sec - _spawn_time_sec < forgive_window:
		return

	if body.is_in_group("player"):
		var v: Vector2 = velocity
		var forward := v.normalized()

		if forward.length() < 0.001:
			forward = Vector2.RIGHT.rotated(global_rotation)

		if body.has_method("_on_projectile_hit"):
			body._on_projectile_hit(forward, v)

		queue_free()

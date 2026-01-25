extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $Sprite

@export var speed = 300.0

func _ready() -> void:
	sprite.play("crawl")

func _physics_process(delta: float) -> void:
	pass

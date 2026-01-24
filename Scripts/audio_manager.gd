extends Node

@onready var bgm = $BGM
@onready var jump = $Jump
@onready var gun_shoot = $GunShoot
@onready var hurt = $Hurt

var bgm_playing = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	bgm_playing = bgm.playing

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _play_bgm() -> void:
	bgm.play()
	bgm_playing = true
	
func _stop_bgm() -> void:
	bgm.stop()
	bgm_playing = false
	
func _play_jump() -> void:
	jump.play()

func _play_gun_shoot() -> void:
	gun_shoot.play()
	
func _play_hurt() -> void:
	hurt.play()

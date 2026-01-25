extends Node

@onready var bgm = $BGM
@onready var jump = $Jump
@onready var gun_shoot = $GunShoot
@onready var hurt = $Hurt

var bgm_playing = false
const SETTINGS_CONFIG_PATH = "user://settings.cfg"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_CONFIG_PATH)
	if err == OK:
		bgm_playing = config.get_value("settings", "music")
		
	if bgm_playing:
		_play_bgm()
	else:
		_stop_bgm()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _play_bgm() -> void:
	var config = ConfigFile.new()

	bgm.play()
	bgm_playing = true
	config.set_value("settings", "music", true)
	var err = config.save(SETTINGS_CONFIG_PATH)
	if err != OK:
		push_warning("AudioManager: Failed to save music settings, error code: %d" % err)

	
func _stop_bgm() -> void:
	var config = ConfigFile.new()
		
	bgm.stop()
	bgm_playing = false
	config.set_value("settings", "music", false)
	var err = config.save(SETTINGS_CONFIG_PATH)
	if err != OK:
		push_warning("AudioManager: Failed to save music settings, error code: %d" % err)
	
func _play_jump() -> void:
	jump.play()

func _play_gun_shoot() -> void:
	gun_shoot.play()
	
func _play_hurt() -> void:
	hurt.play()

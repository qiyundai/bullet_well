extends MarginContainer

@onready var music_button := $Music

@onready var music_off_icon = ResourceLoader.load('res://KenneyUI/PNG/musicOff.png')
@onready var music_on_icon = ResourceLoader.load('res://KenneyUI/PNG/musicOn.png')

@export var audio_player: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	music_button.pressed.connect(_toggle_music)
	music_button.icon = music_on_icon if audio_player.bgm_playing else music_off_icon

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _toggle_music() -> void:
	if audio_player.bgm_playing:
		audio_player._stop_bgm()
	else:
		audio_player._play_bgm()
		
	music_button.icon = music_on_icon if audio_player.bgm_playing else music_off_icon
	music_button.release_focus()

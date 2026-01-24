extends Node

@onready var ui := $"../UICanvas"

func game_over():
	ui.visible = true
	return

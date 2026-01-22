extends Node

func game_over():
	print("GAME OVER")

	# Pause the game
	get_tree().paused = true

	# Optional:
	# show UI
	# restart level
	# play sound

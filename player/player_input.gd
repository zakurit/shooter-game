extends Node

@onready var player := get_parent()

func _input(event):
	if event.is_action_pressed("shoot"):
		# request local shoot (client runs visuals). Actual damage goes via server RPC.
		player.shoot()

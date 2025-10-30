extends Node3D

func _ready():
	# collect spawns into GameState lists
	GameState.red_spawns.clear()
	GameState.blue_spawns.clear()
	for child in get_children():
		if child.name.begins_with("RedSpawn"):
			GameState.red_spawns.append(child)
		elif child.name.begins_with("BlueSpawn"):
			GameState.blue_spawns.append(child)

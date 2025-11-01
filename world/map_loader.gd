extends Node3D

func _ready():
	# Wait one frame to ensure everything is loaded
	await get_tree().process_frame
	
	# Collect spawn points
	GameState.red_spawns.clear()
	GameState.blue_spawns.clear()
	
	_collect_spawns(self)
	
	print("🗺️ Map loaded. Red spawns: ", GameState.red_spawns.size(), " Blue spawns: ", GameState.blue_spawns.size())
	
	# Debug: print spawn positions
	for spawn in GameState.red_spawns:
		print("  Red spawn at: ", spawn.global_position)
	for spawn in GameState.blue_spawns:
		print("  Blue spawn at: ", spawn.global_position)

func _collect_spawns(node: Node):
	# Recursively search for spawn points
	for child in node.get_children():
		if child.name.begins_with("RedSpawn"):
			GameState.red_spawns.append(child)
		elif child.name.begins_with("BlueSpawn"):
			GameState.blue_spawns.append(child)
		
		# Search children recursively
		_collect_spawns(child)

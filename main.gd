extends Node3D

func _ready():
	# Detect server flag (--server) or Godot server feature
	var is_server = OS.has_feature("server") or "-server" in OS.get_cmdline_args()

	if is_server:
		print("Running in SERVER mode")
		NetworkManager.start_server()
	else:
		print("Running in CLIENT mode")
		NetworkManager.start_client()

	# Load the map into the scene root
	var map = load("res://world/map.tscn").instantiate()
	add_child(map)

	# Clients get HUD
	if not is_server:
		var hud = load("res://ui/hud.tscn").instantiate()
		add_child(hud)

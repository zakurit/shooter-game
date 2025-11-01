extends Node3D

func _ready():
	# Check if launched with -server flag
	var is_server := "-server" in OS.get_cmdline_args()
	
	if is_server:
		# DEDICATED SERVER MODE
		print("=== STARTING DEDICATED SERVER ===")
		NetworkManager.start_server()
		
		# Show server GUI (if not headless)
		if not OS.has_feature("headless"):
			var gui = load("res://ui/server_gui.tscn").instantiate()
			add_child(gui)
			print("Server GUI loaded")
	else:
		# CLIENT MODE (from main menu)
		print("=== STARTING CLIENT ===")
		if GameMode.server_ip != "":
			NetworkManager.connect_to_server(GameMode.server_ip, GameMode.server_port)
		else:
			# Fallback to localhost
			NetworkManager.connect_to_server("127.0.0.1", 7777)
		
		# Show HUD
		var hud = load("res://ui/hud.tscn").instantiate()
		add_child(hud)
	
	# Load map (all instances except headless)
	if not OS.has_feature("headless"):
		var map = load("res://world/map.tscn").instantiate()
		add_child(map)
		await map.ready  # Wait for map to finish loading
		print("✅ Map loaded and spawn points collected")

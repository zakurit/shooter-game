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
			var chat_ui = preload("res://ui/chat_ui.tscn").instantiate()
			add_child(chat_ui)
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
		var chat_ui = preload("res://ui/chat_ui.tscn").instantiate()
		add_child(chat_ui)
		
		# Set nickname after player spawns
		await get_tree().create_timer(1.0).timeout
		set_local_player_nickname()
	
	# Load map (all instances except headless)
	if not OS.has_feature("headless"):
		var map = load("res://world/map.tscn").instantiate()
		add_child(map)
		await map.ready  # Wait for map to finish loading
		print("✅ Map loaded and spawn points collected")

func set_local_player_nickname():
	"""Set the local player's nickname from GameMode"""
	var local_player = null
	
	# Find local player
	for node in get_tree().get_nodes_in_group("players"):
		if node.has_method("is_multiplayer_authority") and node.is_multiplayer_authority():
			local_player = node
			break
	
	if local_player and local_player.has_method("set_player_name"):
		local_player.set_player_name(GameMode.player_nickname)
		print("✅ Set nickname to: ", GameMode.player_nickname)
	else:
		# Try again after delay
		print("⚠️ Player not found yet, retrying...")
		await get_tree().create_timer(0.5).timeout
		set_local_player_nickname()

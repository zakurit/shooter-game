extends Node

const PORT := 7777
var peer := ENetMultiplayerPeer.new()

func start_server():
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	print("🖥️ SERVER started on port ", PORT)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func host_server(port: int = PORT):
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port, 8)
	multiplayer.multiplayer_peer = peer
	print("🖥️ SERVER started on port ", port)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func start_client():
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	print("📱 CLIENT connecting to 127.0.0.1:", PORT)
	_connect_client_signals()

func connect_to_server(ip: String, port: int):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	print("📱 CLIENT connecting to ", ip, ":", port)
	_connect_client_signals()

func _connect_client_signals():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_connected_to_server():
	print("✅ Connected to server!")

func _on_connection_failed():
	print("❌ Connection failed")

func _on_peer_connected(id):
	print("Peer connected: ", id)
	
	# SERVER: Handle new peer
	if multiplayer.is_server():
		# Don't spawn for server itself
		if id == 1:
			print("   Ignoring server peer ID")
			return
		
		# Tell the new peer about all existing players FIRST
		var existing_players = get_tree().get_nodes_in_group("players")
		for player in existing_players:
			if player.is_in_group("players") and player.has_method("get_peer_id"):
				var peer_id = player.get_multiplayer_authority()
				var pos = player.global_position
				var team_name = player.team
				print("   📤 Syncing existing player ", peer_id, " to new peer ", id)
				# Send to ONLY the new client
				rpc_id(id, "client_spawn_player", peer_id, team_name, pos)
		
		# Small delay before spawning new player to ensure sync
		await get_tree().create_timer(0.1).timeout
		
		# Now spawn the new player
		spawn_player_for_peer(id)
		
		# Start countdown if enough players
		if multiplayer.get_peers().size() >= 2:
			if not GameState.round_active and not GameState.is_countdown_active:
				print("🎮 Starting countdown!")
				GameState.start_countdown()

func _on_peer_disconnected(id):
	print("Peer disconnected: ", id)
	
	# Clean up player on all clients
	if multiplayer.is_server():
		rpc("client_remove_player", id)
	
	# Clean up locally
	var player = _find_player_by_id(id)
	if player:
		player.queue_free()

@rpc("authority", "call_local")
func client_remove_player(peer_id: int):
	"""Remove a disconnected player"""
	var player = _find_player_by_id(peer_id)
	if player:
		print("🗑️ Removing player ", peer_id)
		player.queue_free()

func spawn_player_for_peer(peer_id: int):
	"""Server spawns a player for a client"""
	if not multiplayer.is_server():
		return
	
	print("🎮 Spawning NEW player for peer ", peer_id)
	
	var player_scene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	player.team = GameState.assign_team(peer_id)
	
	# Add to tree FIRST before anything else
	get_tree().current_scene.add_child(player)
	
	# Now set authority and position (node is in tree)
	player.set_multiplayer_authority(peer_id)
	
	var spawn_pos = GameState.random_spawn(player.team)
	player.global_position = spawn_pos
	
	print("   ✅ Spawned at ", spawn_pos, " team: ", player.team)
	
	# Tell ALL clients to spawn this NEW player
	rpc("client_spawn_player", peer_id, player.team, spawn_pos)

@rpc("authority", "call_local")
func client_spawn_player(peer_id: int, team: String, spawn_pos: Vector3):
	"""Clients spawn a player instance"""
	# Server already spawned it locally
	if multiplayer.is_server():
		return
	
	# Don't spawn duplicates
	var existing = _find_player_by_id(peer_id)
	if existing:
		print("⚠️ Player ", peer_id, " already exists, skipping")
		return
	
	print("📱 CLIENT: Spawning player ", peer_id, " team: ", team)
	
	var player_scene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	player.team = team
	
	# FIX: Add to tree BEFORE setting authority and position
	get_tree().current_scene.add_child(player)
	
	# Now it's safe to set these
	player.set_multiplayer_authority(peer_id)
	player.global_position = spawn_pos
	
	# Initialize remote state to prevent snapping
	if not player.is_multiplayer_authority():
		player.remote_position = spawn_pos
		player.remote_rotation = 0
		player.remote_cam_pitch = 0
		player.remote_crouching = false
	
	# Debug: Verify visibility
	if player.is_multiplayer_authority():
		print("   ✅ My player spawned")
	else:
		print("   ✅ Remote player spawned (should be visible)")

func _find_player_by_id(id: int):
	for node in get_tree().get_nodes_in_group("players"):
		if node.has_method("get_multiplayer_authority") and node.get_multiplayer_authority() == id:
			return node
	return null

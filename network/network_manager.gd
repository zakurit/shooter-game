extends Node

const PORT := 7777
var peer: ENetMultiplayerPeer = null
var map_ready: bool = false

func _init():
	peer = ENetMultiplayerPeer.new()

func _ready():
	# Listen for map ready signal
	await get_tree().process_frame
	_check_map_ready()

func _check_map_ready():
	# Wait until spawn points are populated
	while GameState.red_spawns.size() == 0 or GameState.blue_spawns.size() == 0:
		await get_tree().create_timer(0.1).timeout
	
	map_ready = true
	print("✅ Map is ready, can spawn players now")

func start_server():
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	print("🖥️ SERVER started on port ", PORT)

	# Connect signals once
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func host_server(port: int = PORT):
	# Alias of start_server with custom port
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port, 8)
	multiplayer.multiplayer_peer = peer
	print("🖥️ SERVER started on port ", port)

	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func start_client():
	# Always create a fresh peer for client
	peer = ENetMultiplayerPeer.new()
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
	# Avoid duplicate connects
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
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

		# CRITICAL: Wait for map to be ready before spawning
		if not map_ready:
			print("   ⏳ Waiting for map to load...")
			while not map_ready:
				await get_tree().create_timer(0.1).timeout
			print("   ✅ Map ready, proceeding with spawn")

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

@rpc("any_peer", "call_local")
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

	# IMPORTANT: Set authority BEFORE adding the node to the scene tree
	player.set_multiplayer_authority(peer_id)

	# CRITICAL FIX: Add to scene FIRST, then set position
	get_tree().current_scene.add_child(player)
	
	# Wait one physics frame to ensure collision is ready
	await get_tree().process_frame
	
	# Now set position AFTER it's in the tree
	var spawn_pos = GameState.random_spawn(player.team)
	player.global_position = spawn_pos

	print("   ✅ Spawned at ", spawn_pos, " team: ", player.team)

	# Tell ALL clients to spawn this NEW player (server will ignore because it already spawned)
	rpc("client_spawn_player", peer_id, player.team, spawn_pos)

@rpc("any_peer", "call_local")
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
	
	# CRITICAL: Client must also wait for map to load
	if GameState.red_spawns.size() == 0 or GameState.blue_spawns.size() == 0:
		print("📱 CLIENT: Waiting for map before spawning player ", peer_id)
		while GameState.red_spawns.size() == 0 or GameState.blue_spawns.size() == 0:
			await get_tree().create_timer(0.1).timeout
		print("📱 CLIENT: Map ready, now spawning player ", peer_id)

	print("📱 CLIENT: Spawning player ", peer_id, " team: ", team)

	var player_scene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	player.team = team
	
	# CRITICAL: Set authority BEFORE adding to tree
	# This ensures _ready() sees the correct authority
	player.set_multiplayer_authority(peer_id)

	# Now add to tree - _ready() will run with correct authority
	get_tree().current_scene.add_child(player)
	
	# Wait one frame for physics
	await get_tree().process_frame

	# Set position after physics is ready
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

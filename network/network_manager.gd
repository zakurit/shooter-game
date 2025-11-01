extends Node

const PORT := 7777
var peer := ENetMultiplayerPeer.new()

func start_server():
	"""Start server on default port (for command-line launch)"""
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	print("SERVER started on port ", PORT)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func host_server(port: int = PORT):
	"""Start server with custom port (from menu)"""
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port, 8)
	multiplayer.multiplayer_peer = peer
	print("SERVER started on port ", port)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func start_client():
	"""Connect to localhost (for command-line launch)"""
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	print("CLIENT connecting to 127.0.0.1:", PORT)
	_connect_client_signals()

func connect_to_server(ip: String, port: int):
	"""Connect client to specific IP and port (from menu)"""
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	print("CLIENT connecting to ", ip, ":", port)
	_connect_client_signals()

func _connect_client_signals():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_connected_to_server():
	print("✅ CLIENT: Successfully connected to server!")

func _on_connection_failed():
	print("❌ CLIENT: Failed to connect to server")

func _on_peer_connected(id):
	print("!!! Peer connected: ", id, " (I am: ", multiplayer.get_unique_id(), ")")
	
	if multiplayer.is_server():
		print("SERVER: Spawning player for peer ", id)
		
		# Spawn all existing players for the new client
		for existing_id in multiplayer.get_peers():
			if existing_id != id:
				var existing_player = _find_player_by_id(existing_id)
				if existing_player:
					rpc_id(id, "spawn_player", existing_id, existing_player.team, existing_player.global_position)
		
		# Now spawn the new player
		var player_scene = load("res://player/player.tscn")
		var player = player_scene.instantiate()
		player.name = "Player_" + str(id)
		player.set_multiplayer_authority(id)
		player.team = GameState.assign_team(id)
		get_tree().current_scene.add_child(player)
		player.global_position = GameState.random_spawn(player.team)
		
		print("SERVER: Player spawned at ", player.global_position, " team: ", player.team)
		
		# Tell ALL clients to spawn this player
		rpc("spawn_player", id, player.team, player.global_position)
		
		# START COUNTDOWN when we have 2+ players
		if multiplayer.get_peers().size() >= 2 and not GameState.round_active and not GameState.is_countdown_active:
			print("SERVER: Starting countdown - enough players!")
			GameState.start_countdown()

func _on_peer_disconnected(id):
	print("Peer disconnected:", id)

func _find_player_by_id(id: int) -> Player:
	for node in get_tree().get_nodes_in_group("players"):
		if node.get_multiplayer_authority() == id:
			return node
	return null

@rpc("any_peer", "call_local")
func spawn_player(id: int, team: String, position: Vector3):
	if multiplayer.is_server():
		return
	
	if _find_player_by_id(id):
		print("CLIENT: Player ", id, " already exists, skipping")
		return
	
	print("CLIENT: Spawning player ", id, " at ", position, " team: ", team)
	var player_scene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player_" + str(id)
	player.set_multiplayer_authority(id)
	player.team = team
	get_tree().current_scene.add_child(player)
	player.global_position = position

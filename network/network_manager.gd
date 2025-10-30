extends Node

const PORT := 7777
var peer := ENetMultiplayerPeer.new()

func start_server():
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	print("SERVER started on port", PORT)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func start_client():
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	print("CLIENT connecting to 127.0.0.1:", PORT)

func _on_peer_connected(id):
	print("Peer connected:", id)

	# SERVER SPAWNS THE PLAYER
	if multiplayer.is_server():
		var player_scene = load("res://player/player.tscn")
		var player = player_scene.instantiate()

		player.set_multiplayer_authority(id)
		player.team = GameState.assign_team(id)
		player.global_position = GameState.random_spawn(player.team)

		get_tree().current_scene.add_child(player)

func _on_peer_disconnected(id):
	print("Peer disconnected:", id)

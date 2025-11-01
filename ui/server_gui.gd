extends Control

@onready var players_label: Label = $VBoxContainer/PlayersLabel
@onready var fps_label: Label = $VBoxContainer/FpsLabel

func _ready() -> void:
	var args = OS.get_cmdline_args()
	var is_server = "--server" in args or "-server" in args
	visible = is_server
	
	set_process(true)

func _process(delta: float) -> void:
	if not visible:
		return

	var peer_count: int = 0
	var ping_text: String = ""

	# Get peer IDs from the multiplayer API
	var peer_ids: Array = multiplayer.get_peers()
	peer_count = peer_ids.size()
	
	# For each peer, try to get ping info
	for peer_id in peer_ids:
		# Try to access the underlying ENet connection
		var enet_peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if enet_peer and enet_peer.host:
			var packet_peers: Array = enet_peer.host.get_peers()
			# Find the matching packet peer for this ID
			for packet_peer_obj in packet_peers:
				var packet_peer: ENetPacketPeer = packet_peer_obj as ENetPacketPeer
				if packet_peer and packet_peer.get_remote_address() != "":
					var rtt: int = packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
					ping_text += "Peer %d: %d ms\n" % [peer_id, rtt]
					break
		else:
			# Fallback if we can't get ping
			ping_text += "Peer %d: N/A\n" % peer_id

	players_label.text = "Players Connected: %d\n%s" % [peer_count, ping_text]
	fps_label.text = "Server FPS: %d" % Engine.get_frames_per_second()

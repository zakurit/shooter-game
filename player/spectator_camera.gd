extends Camera3D

var spectating_index: int = 0
var locked_target = null

func _ready():
	# Only active on server
	if not multiplayer.is_server():
		queue_free()
		return
	
	print("👁️ Spectator camera active")
	current = true
	
	# Lock to first player after a moment
	await get_tree().create_timer(1.0).timeout
	lock_to_index(0)

func _input(event):
	if not multiplayer.is_server():
		return
	
	# Click to cycle
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cycle_player()

func _physics_process(_delta):
	if not multiplayer.is_server():
		return
	
	# Validate target
	if locked_target == null or not is_instance_valid(locked_target):
		lock_to_index(spectating_index)
		return
	
	if locked_target.has_node("Camera3D"):
		var target_cam = locked_target.get_node("Camera3D")
		global_transform = target_cam.global_transform

func lock_to_index(index: int) -> void:
	"""Lock camera to a specific player index (safe if no players exist)."""
	var players = get_tree().get_nodes_in_group("players")

	if players.is_empty():
		spectating_index = -1
		locked_target = null
		print("👁️ No players to spectate.")
		return

	# Clamp index within range
	spectating_index = clamp(index, 0, players.size() - 1)
	locked_target = players[spectating_index]

	print("👁️ LOCKED to ", locked_target.name, " [", spectating_index + 1, "/", players.size(), "]")

func cycle_player():
	var players = get_tree().get_nodes_in_group("players")
	
	if players.size() == 0:
		print("👁️ No players to spectate")
		return
	
	spectating_index = (spectating_index + 1) % players.size()
	lock_to_index(spectating_index)

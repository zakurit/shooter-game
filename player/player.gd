extends CharacterBody3D
class_name Player

@export var speed: float = 18
@export var crouch_speed: float = 9
@export var jump_velocity: float = 8.0
@export var mouse_sensitivity: float = 0.002
@export var vertical_look_limit: float = 89.0
@export var gravity: float = 20.0

var team: String = ""
var health: int = 100
var is_dead: bool = false
var camera_rotation: Vector2 = Vector2.ZERO
var is_crouching: bool = false

# Server state (what server knows)
var server_position: Vector3
var server_rotation: float
var server_velocity: Vector3
var server_crouching: bool

# Client interpolation
var remote_position: Vector3
var remote_rotation: float
var remote_cam_pitch: float
var remote_crouching: bool

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
var standing_height: float = 2.0
var crouch_height: float = 1.0

# 128 tick
const TICK_RATE = 128
var tick_timer: float = 0.0
var tick_interval: float = 1.0 / TICK_RATE

func _ready():
	add_to_group("players")
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		standing_height = collision_shape.shape.height
		crouch_height = standing_height / 2.0
	
	# Wait a frame for multiplayer authority to be set
	await get_tree().process_frame
	
	# Only activate camera for the LOCAL player
	if is_multiplayer_authority():
		if has_node("Camera3D"):
			$Camera3D.current = true
			print("✅ Camera ACTIVE for ", name, " (peer ", get_multiplayer_authority(), ")")
			print("   My peer ID: ", multiplayer.get_unique_id())
	else:
		if has_node("Camera3D"):
			$Camera3D.current = false
			print("📷 Camera INACTIVE for ", name, " (remote player, owner: ", get_multiplayer_authority(), ")")
		remote_position = global_position
		remote_rotation = rotation.y
		remote_cam_pitch = 0
		remote_crouching = false

func get_peer_id() -> int:
	"""Helper to get this player's peer ID"""
	return get_multiplayer_authority()

func _unhandled_input(event):
	# CRITICAL: Only the OWNING client processes input
	if not is_multiplayer_authority():
		return
	
	if is_dead:
		return
	
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		print("🖱️ Mouse captured on ", name)
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.y -= event.relative.x * mouse_sensitivity
		camera_rotation.x -= event.relative.y * mouse_sensitivity
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(-vertical_look_limit), deg_to_rad(vertical_look_limit))

func _process(delta: float) -> void:
	# Local player: apply camera rotation immediately
	if is_multiplayer_authority() and not is_dead:
		rotation.y = camera_rotation.y
		if has_node("Camera3D"):
			$Camera3D.rotation.x = camera_rotation.x
	
	# Remote players: smooth interpolation
	elif not is_multiplayer_authority():
		global_position = global_position.lerp(remote_position, delta * 20.0)
		rotation.y = lerp_angle(rotation.y, remote_rotation, delta * 20.0)
		if has_node("Camera3D"):
			$Camera3D.rotation.x = lerp_angle($Camera3D.rotation.x, remote_cam_pitch, delta * 20.0)
		
		# Apply crouch state
		if is_crouching != remote_crouching:
			apply_crouch_visual(remote_crouching)

func _physics_process(delta: float) -> void:
	# CRITICAL: Only the OWNING client runs physics
	if not is_multiplayer_authority():
		return
	
	if is_dead:
		velocity = Vector3.ZERO
		return
	
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	# Crouch (local only)
	var want_crouch = Input.is_action_pressed("crouch")
	if is_crouching != want_crouch:
		is_crouching = want_crouch
		apply_crouch_visual(want_crouch)
	
	# Movement
	var current_speed = crouch_speed if is_crouching else speed
	var dir := Vector3.ZERO
	dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	dir.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	
	if dir.length() > 0.001:
		dir = dir.normalized()
	
	var move_vec := (global_transform.basis * dir)
	velocity.x = move_vec.x * current_speed
	velocity.z = move_vec.z * current_speed
	move_and_slide()
	
	# Send state to server at 128 tick
	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		send_input_to_server()

func apply_crouch_visual(crouching: bool):
	"""Apply visual crouch locally - no networking"""
	if not collision_shape or not collision_shape.shape is CapsuleShape3D:
		return
	
	if crouching:
		collision_shape.shape.height = crouch_height
		if has_node("Camera3D"):
			$Camera3D.position.y = crouch_height / 2.0
	else:
		collision_shape.shape.height = standing_height
		if has_node("Camera3D"):
			$Camera3D.position.y = standing_height / 2.0

func send_input_to_server():
	"""Send client state to server (128 tick)"""
	if not is_multiplayer_authority():
		return
	
	# Don't send if we ARE the server (dedicated server case)
	if multiplayer.is_server():
		return
	
	# Send to server
	rpc_id(1, "server_receive_input", global_position, rotation.y, camera_rotation.x, velocity, is_crouching)

@rpc("any_peer", "call_remote", "unreliable")
func server_receive_input(pos: Vector3, rot_y: float, cam_pitch: float, vel: Vector3, crouching: bool):
	"""Server receives client input and broadcasts to others"""
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var owner_id = get_multiplayer_authority()
	
	# CRITICAL: Verify this is the correct player node for this sender
	if sender_id != owner_id:
		# This is the wrong player node - silently ignore
		return
	
	# Server stores authoritative state
	server_position = pos
	server_rotation = rot_y
	server_velocity = vel
	server_crouching = crouching
	
	# Update server-side position
	global_position = pos
	rotation.y = rot_y
	velocity = vel
	
	# Broadcast to ALL clients EXCEPT the owner of THIS player
	var all_peers = multiplayer.get_peers()
	
	# Debug print occasionally
	if randf() < 0.01:  # 1% of frames
		print("📡 Broadcasting ", name, " (owner:", owner_id, ") to peers:", all_peers, " (excluding owner)")
	
	for peer_id in all_peers:
		if peer_id != owner_id:  # Use owner_id instead of sender_id
			rpc_id(peer_id, "client_receive_state", pos, rot_y, cam_pitch, vel, crouching)

@rpc("any_peer", "call_remote", "unreliable")
func client_receive_state(pos: Vector3, rot_y: float, cam_pitch: float, vel: Vector3, crouching: bool):
	"""Clients receive state updates from server"""
	# Only accept from server
	if multiplayer.get_remote_sender_id() != 1:
		return
	
	# FIX: Ignore if this is my own player
	if is_multiplayer_authority():
		return
	
	# Store for interpolation
	remote_position = pos
	remote_rotation = rot_y
	remote_cam_pitch = cam_pitch
	remote_crouching = crouching

func shoot() -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	
	var ray_length: float = 100.0
	var from: Vector3 = $Camera3D.global_transform.origin
	var to: Vector3 = from + ($Camera3D.global_transform.basis.z * -ray_length)
	
	var space_state := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = [self]
	
	var result := space_state.intersect_ray(params)
	
	if result and result.has("collider"):
		var collider: Node = result["collider"]
		
		if collider.is_in_group("players") and collider.has_method("get_peer_id"):
			if not collider.is_player_dead():
				var target_peer_id = collider.get_peer_id()
				rpc_id(1, "server_process_hit", target_peer_id)

@rpc("any_peer", "call_remote")
func server_process_hit(target_peer_id: int):
	"""Server processes hit registration"""
	if not multiplayer.is_server():
		return
	
	var target = _find_player_by_peer_id(target_peer_id)
	if not target or target.is_dead:
		return
	
	print("💥 Hit confirmed: ", target.name)
	target.server_apply_damage(100)

func _find_player_by_peer_id(peer_id: int) -> Player:
	"""Helper to find player by their peer ID"""
	for node in get_tree().get_nodes_in_group("players"):
		if node is Player and node.get_multiplayer_authority() == peer_id:
			return node
	return null

func server_apply_damage(amount: int):
	"""Server applies damage (authoritative)"""
	if not multiplayer.is_server() or is_dead:
		return
	
	health -= amount
	print("💔 ", name, " took ", amount, " damage. HP: ", health)
	
	# Notify owner
	rpc_id(get_multiplayer_authority(), "client_sync_health", health)
	
	if health <= 0:
		server_kill_player()

@rpc("authority", "call_local")
func client_sync_health(new_health: int):
	health = new_health

func server_kill_player():
	"""Server handles player death"""
	if not multiplayer.is_server() or is_dead:
		return
	
	is_dead = true
	velocity = Vector3.ZERO
	
	print("☠️ ", name, " (", team, ") died")
	
	# Tell ALL clients this player is dead
	rpc("client_player_died")
	
	# Notify game state
	GameState.on_player_died(team)

@rpc("authority", "call_local")
func client_player_died():
	"""All clients mark player as dead"""
	is_dead = true
	velocity = Vector3.ZERO
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	# Disable input if this is my player
	if is_multiplayer_authority():
		set_process_input(false)
		set_process_unhandled_input(false)

func is_player_dead() -> bool:
	return is_dead

@rpc("any_peer", "call_local", "reliable")
func force_respawn(spawn_pos: Vector3):
	"""Server commands respawn - called locally on server, synced to clients"""
	# Only server can call this
	if multiplayer.get_remote_sender_id() != 1 and not multiplayer.is_server():
		print("⚠️ force_respawn rejected from non-server")
		return
	
	print("🔄 force_respawn() called on ", name, " | Server: ", multiplayer.is_server(), " | Authority: ", is_multiplayer_authority(), " | Peer: ", multiplayer.get_unique_id())
	
	is_dead = false
	health = 100
	global_position = spawn_pos
	velocity = Vector3.ZERO
	
	# Reset interpolation
	remote_position = spawn_pos
	server_position = spawn_pos
	
	camera_rotation = Vector2.ZERO
	rotation.y = 0
	if has_node("Camera3D"):
		$Camera3D.rotation.x = 0
	
	is_crouching = false
	apply_crouch_visual(false)
	
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	# Re-enable input
	if is_multiplayer_authority():
		set_process_input(true)
		set_process_unhandled_input(true)
		print("   ✅ Input re-enabled for MY player")
	
	print("   ✅ Respawn complete at ", global_position)

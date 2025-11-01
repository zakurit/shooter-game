extends CharacterBody3D
class_name Player

@export var speed: float = 18
@export var mouse_sensitivity: float = 0.002
@export var vertical_look_limit: float = 89.0

var team: String = ""
var health: int = 100
var is_dead: bool = false
var camera_rotation: Vector2 = Vector2.ZERO

# For remote player interpolation
var remote_position: Vector3
var remote_rotation_y: float
var remote_cam_pitch: float

func _ready():
	add_to_group("players")
	
	print("Player spawned: ", name, " Authority: ", get_multiplayer_authority(), " My ID: ", multiplayer.get_unique_id())
	
	# Make camera active ONLY for the player I control
	if is_multiplayer_authority():
		if has_node("Camera3D"):
			$Camera3D.current = true
			print("✅ Camera activated for player: ", name)
		else:
			print("❌ No Camera3D found on player!")
	else:
		# Disable camera for remote players
		if has_node("Camera3D"):
			$Camera3D.current = false
		# Initialize interpolation targets
		remote_position = global_transform.origin
		remote_rotation_y = rotation.y
		remote_cam_pitch = 0

func _unhandled_input(event):
	if not is_multiplayer_authority() or is_dead:
		return
	
	# Capture mouse on ANY mouse button press
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	
	# Release mouse on ESC
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Mouse look - ONLY if captured
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.y -= event.relative.x * mouse_sensitivity
		camera_rotation.x -= event.relative.y * mouse_sensitivity
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(-vertical_look_limit), deg_to_rad(vertical_look_limit))

func _process(delta: float) -> void:
	# Apply camera rotation at 180Hz for local player
	if is_multiplayer_authority() and not is_dead:
		rotation.y = camera_rotation.y
		if has_node("Camera3D"):
			$Camera3D.rotation.x = camera_rotation.x
	
	# Interpolate remote players for smooth 180Hz visuals
	if not is_multiplayer_authority():
		global_transform.origin = global_transform.origin.lerp(remote_position, delta * 40.0)
		rotation.y = lerp_angle(rotation.y, remote_rotation_y, delta * 40.0)
		if has_node("Camera3D"):
			$Camera3D.rotation.x = lerp_angle($Camera3D.rotation.x, remote_cam_pitch, delta * 40.0)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and not is_dead:
		# Movement only (camera rotation now handled in _process at 180Hz)
		var dir := Vector3.ZERO
		dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		dir.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
		
		if dir.length() > 0.001:
			dir = dir.normalized()
		
		var move_vec := (global_transform.basis * dir)
		velocity.x = move_vec.x * speed
		velocity.z = move_vec.z * speed
		move_and_slide()
		
		# Send position + rotation to other clients (60Hz from physics)
		rpc("sync_transform", global_transform.origin, rotation.y, camera_rotation.x)

@rpc("any_peer", "unreliable_ordered")
func sync_transform(pos: Vector3, rot_y: float, cam_pitch: float) -> void:
	if not is_multiplayer_authority():
		# Store for interpolation in _process
		remote_position = pos
		remote_rotation_y = rot_y
		remote_cam_pitch = cam_pitch

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
		
		if collider.is_in_group("players") and collider.has_method("is_player_dead"):
			if not collider.is_player_dead():
				rpc_id(1, "server_apply_damage", collider.get_path(), 100)

func is_player_dead() -> bool:
	return is_dead

@rpc("any_peer", "call_remote")
func server_apply_damage(target_path: NodePath, amount: int) -> void:
	if not multiplayer.is_server():
		return
	
	var target := get_node_or_null(target_path)
	
	if target and target.has_method("take_damage") and not target.is_dead:
		target.take_damage(amount)

func take_damage(amount: int) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	
	health -= amount
	
	rpc_id(get_multiplayer_authority(), "sync_health", health)
	
	if health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	
	GameState.on_player_died(team)
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	rpc("set_dead_state", true)
	
	if multiplayer.is_server():
		var spawn_pos = GameState.random_spawn(team)
		force_respawn(spawn_pos)
		rpc_id(get_multiplayer_authority(), "force_respawn", spawn_pos)

@rpc("any_peer", "call_local")
func set_dead_state(dead: bool):
	is_dead = dead
	set_collision_layer_value(1, not dead)
	set_collision_mask_value(1, not dead)

@rpc("any_peer", "call_local")
func sync_health(new_health: int):
	health = new_health

@rpc("any_peer", "call_local")
func force_respawn(spawn_pos: Vector3):
	is_dead = false
	health = 100
	global_position = spawn_pos
	velocity = Vector3.ZERO
	
	# Update interpolation targets for remote players
	if not is_multiplayer_authority():
		remote_position = spawn_pos
	
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	camera_rotation = Vector2.ZERO
	rotation.y = 0
	if has_node("Camera3D"):
		$Camera3D.rotation.x = 0
	
	set_physics_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)

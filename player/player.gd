extends CharacterBody3D
class_name Player

@export var speed: float = 8
@export var crouch_speed: float = 4
@export var jump_velocity: float = 8
@export var jump_speed_retention: float = 1.0
@export var mouse_sensitivity: float = 0.002
@export var vertical_look_limit: float = 89.0
@export var gravity: float = 20.0
@export var air_accelerate: float = 10.0
@export var air_speed_cap: float = 1.2
@export var air_resistance: float = 0.98
@export var ground_friction: float = 6.0
var team: String = ""
var health: int = 100
var is_dead: bool = false
var camera_rotation: Vector2 = Vector2.ZERO
var is_crouching: bool = false
var player_name: String = "Player"
# Long jump tracking
var is_jumping: bool = false
var jump_start_pos: Vector3 = Vector3.ZERO
var jump_strafe_count: int = 0
var jump_sync_count: int = 0
var last_air_direction: float = 0.0
var was_on_ground: bool = true
# Stats
var current_speed: float = 0.0
var best_jump_distance: float = 0.0
var best_jump_strafes: int = 0
# Server state
var server_position: Vector3
var server_rotation: float
var server_velocity: Vector3
var server_crouching: bool
# Client interpolation
var remote_position: Vector3
var remote_rotation: float
var remote_cam_pitch: float
var remote_crouching: bool
var remote_player_name: String = ""

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var gun_animator: AnimationPlayer = null

# Audio players
@onready var shoot_audio: AudioStreamPlayer = null
@onready var kill_audio: AudioStreamPlayer = null

var standing_height: float = 2.0
var crouch_height: float = 1.0
var standing_camera_height: float = 0.8
var crouch_camera_height: float = 0.3

# 128 tick
const TICK_RATE = 128
var tick_timer: float = 0.0
const TICK_INTERVAL = 1.0 / 128.0

func _ready():
	add_to_group("players")
	
	# Get gun animator if it exists
	if has_node("Camera3D/GunViewmodel/ak_tex/AnimationPlayer"):
		gun_animator = $Camera3D/GunViewmodel/ak_tex/AnimationPlayer
		print("✅ Gun animator found")
	
	# Setup audio players
	setup_audio()
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		standing_height = collision_shape.shape.height
		crouch_height = standing_height / 2.0
		standing_camera_height = standing_height * 0.4
		crouch_camera_height = crouch_height * 0.3
	
	# CRITICAL: Disable ALL cameras by default IMMEDIATELY to prevent race condition
	if has_node("Camera3D"):
		$Camera3D.current = false
	
	await get_tree().process_frame
	
	if not multiplayer or not multiplayer.multiplayer_peer:
		print("⚠️ Multiplayer not ready for ", name)
		return
	
	# Small delay to ensure all clients have spawned this player
	if not multiplayer.is_server():
		await get_tree().create_timer(0.2).timeout
	
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.use_accumulated_input = false
		
		if has_node("Camera3D"):
			$Camera3D.current = true
			$Camera3D.position.y = standing_camera_height
			print("✅ Camera ACTIVE for ", name, " (peer ", get_multiplayer_authority(), ")")
			print("   🖱️ Mouse captured with RAW INPUT!")
	else:
		if has_node("Camera3D"):
			$Camera3D.current = false
			print("📷 Camera INACTIVE for ", name, " (remote player)")
		remote_position = global_position
		remote_rotation = rotation.y
		remote_cam_pitch = 0
		remote_crouching = false

func setup_audio():
	"""Create and configure audio players for shooting and kill sounds"""
	# Create shoot audio player
	shoot_audio = AudioStreamPlayer.new()
	shoot_audio.name = "ShootAudio"
	shoot_audio.bus = "Master"
	
	# Load shoot sound
	var shoot_sound = load("res://audio/shoot.mp3")
	if shoot_sound:
		shoot_audio.stream = shoot_sound
		print("✅ Shoot sound loaded")
	else:
		print("⚠️ Failed to load shoot.mp3")
	
	add_child(shoot_audio)
	
	# Create kill audio player
	kill_audio = AudioStreamPlayer.new()
	kill_audio.name = "KillAudio"
	kill_audio.bus = "Master"
	
	# Load kill sound
	var kill_sound = load("res://audio/kill.mp3")
	if kill_sound:
		kill_audio.stream = kill_sound
		print("✅ Kill sound loaded")
	else:
		print("⚠️ Failed to load kill.mp3")
	
	add_child(kill_audio)

func play_shoot_sound():
	"""Play shooting sound (stops previous if playing)"""
	if shoot_audio:
		shoot_audio.stop()  # Stop any currently playing shot
		shoot_audio.play()

func play_kill_sound():
	"""Play kill sound"""
	if kill_audio:
		kill_audio.play()

func set_player_name(new_name: String):
	"""Set player nickname"""
	player_name = new_name
	if is_multiplayer_authority() and multiplayer.is_server():
		rpc("sync_player_name", new_name)
	elif is_multiplayer_authority():
		rpc_id(1, "server_set_player_name", new_name)

@rpc("any_peer", "call_remote")
func server_set_player_name(new_name: String):
	"""Server receives name from client"""
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != get_multiplayer_authority():
		return
	
	player_name = new_name
	rpc("sync_player_name", new_name)

@rpc("any_peer", "call_local")
func sync_player_name(new_name: String):
	"""All clients sync player name"""
	if multiplayer.get_remote_sender_id() != 1 and not multiplayer.is_server():
		return
	player_name = new_name
	remote_player_name = new_name

func get_peer_id() -> int:
	return get_multiplayer_authority()

func get_player_name() -> String:
	"""Get the player's display name"""
	return player_name

func _unhandled_input(event):
	if not multiplayer or not multiplayer.multiplayer_peer:
		return
	
	if not is_multiplayer_authority():
		return
	
	if is_dead:
		return
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.y -= event.relative.x * mouse_sensitivity
		camera_rotation.x -= event.relative.y * mouse_sensitivity
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(-vertical_look_limit), deg_to_rad(vertical_look_limit))

func _process(delta: float) -> void:
	if not multiplayer or not multiplayer.multiplayer_peer:
		return
	
	var is_auth = is_multiplayer_authority()
	
	if is_auth and not is_dead:
		rotation.y = camera_rotation.y
		if has_node("Camera3D"):
			$Camera3D.rotation.x = camera_rotation.x
		
		var horizontal_vel = Vector2(velocity.x, velocity.z)
		current_speed = horizontal_vel.length()
		
		tick_timer += delta
		if tick_timer >= TICK_INTERVAL:
			tick_timer = 0.0
			send_input_to_server()
	
	elif not is_auth:
		global_position = global_position.lerp(remote_position, delta * 20.0)
		rotation.y = lerp_angle(rotation.y, remote_rotation, delta * 20.0)
		
		if collision_shape and collision_shape.shape is CapsuleShape3D:
			var target_height = crouch_height if remote_crouching else standing_height
			if abs(collision_shape.shape.height - target_height) > 0.01:
				print("🔧 Updating ", name, " collision: ", collision_shape.shape.height, " -> ", target_height, " (remote_crouch=", remote_crouching, ")")
				collision_shape.shape.height = target_height

func _physics_process(delta: float) -> void:
	if not multiplayer or not multiplayer.multiplayer_peer:
		return
	
	if not is_multiplayer_authority():
		return
	
	if is_dead:
		velocity = Vector3.ZERO
		return
	
	var on_ground = is_on_floor()
	
	if on_ground and not was_on_ground:
		if is_jumping:
			var distance = Vector2(global_position.x - jump_start_pos.x, global_position.z - jump_start_pos.z).length()
			
			if distance > best_jump_distance:
				best_jump_distance = distance
			if jump_strafe_count > best_jump_strafes:
				best_jump_strafes = jump_strafe_count
			
			print("🏃 JUMP: %.2fm | Strafes: %d | Sync: %d | Best: %.2fm" % [distance, jump_strafe_count, jump_sync_count, best_jump_distance])
			is_jumping = false
	
	if not on_ground:
		velocity.y -= gravity * delta
		velocity.x *= air_resistance
		velocity.z *= air_resistance
	
	if Input.is_action_just_pressed("jump") and on_ground:
		var pre_jump_horizontal = Vector2(velocity.x, velocity.z).length()
		
		velocity.y = jump_velocity
		
		var post_jump_horizontal = Vector2(velocity.x, velocity.z).length()
		print("🔍 JUMP: Horiz: %.1f | Y: %.1f | Total: %.1f" % [
			post_jump_horizontal, 
			velocity.y, 
			velocity.length()
		])
		
		is_jumping = true
		jump_start_pos = global_position
		jump_strafe_count = 0
		jump_sync_count = 0
		last_air_direction = 0.0
	
	var want_crouch = Input.is_action_pressed("crouch")
	if is_crouching != want_crouch:
		is_crouching = want_crouch
		print("🐛 LOCAL crouch changed: ", name, " | is_crouching=", is_crouching)
		apply_crouch_visual(want_crouch)
		
		if not multiplayer.is_server():
			pass
	
	var move_speed = crouch_speed if is_crouching else speed
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	
	if input_dir.length() > 0.001:
		input_dir = input_dir.normalized()
	
	if on_ground:
		if input_dir.length() > 0.001:
			var move_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
			var speed_current = horizontal_vel.length()
			if speed_current > 0.1:
				var friction = ground_friction * delta
				var new_speed = max(0.0, speed_current - friction * speed_current)
				var scale = new_speed / speed_current
				velocity.x *= scale
				velocity.z *= scale
			else:
				velocity.x = 0
				velocity.z = 0
	else:
		if input_dir.length() > 0.001:
			var wish_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			air_strafe(wish_dir, move_speed, delta)
			
			if is_jumping:
				var current_direction = atan2(input_dir.x, input_dir.y)
				if abs(angle_difference(current_direction, last_air_direction)) > 0.5:
					jump_strafe_count += 1
					
					var velocity_angle = atan2(velocity.x, velocity.z)
					var look_angle = rotation.y
					if abs(angle_difference(velocity_angle, look_angle)) < 0.3:
						jump_sync_count += 1
					
					last_air_direction = current_direction
	
	was_on_ground = on_ground
	move_and_slide()
	
	if global_position.y < -50:
		print("⚠️ Player fell through world! Resetting...")
		global_position = Vector3(0, 10, 0)
		velocity = Vector3.ZERO

func air_strafe(wish_dir: Vector3, max_speed: float, delta: float):
	"""TRUE CS 1.6 air strafing mechanics"""
	var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
	var current_speed = horizontal_vel.length()
	
	var wish_speed = max_speed * air_speed_cap
	var current_speed_in_wish_dir = horizontal_vel.dot(wish_dir)
	var add_speed_cap = wish_speed - current_speed_in_wish_dir
	
	if add_speed_cap <= 0:
		return
	
	var accel_speed = air_accelerate * max_speed * delta
	
	if accel_speed > add_speed_cap:
		accel_speed = add_speed_cap
	
	velocity.x += wish_dir.x * accel_speed
	velocity.z += wish_dir.z * accel_speed

func angle_difference(a: float, b: float) -> float:
	var diff = fmod(a - b, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return diff

func apply_crouch_visual(crouching: bool):
	if not collision_shape or not collision_shape.shape is CapsuleShape3D:
		return
	
	print("🐛 apply_crouch_visual: ", name, " | Auth: ", is_multiplayer_authority(), " | Crouch: ", crouching)
	
	if crouching:
		collision_shape.shape.height = crouch_height
	else:
		collision_shape.shape.height = standing_height
	
	if is_multiplayer_authority() and has_node("Camera3D"):
		if crouching:
			$Camera3D.position.y = crouch_camera_height
		else:
			$Camera3D.position.y = standing_camera_height

func send_input_to_server():
	if not is_multiplayer_authority():
		return
	
	if not multiplayer or not multiplayer.multiplayer_peer:
		return
	
	if multiplayer.is_server():
		return
	
	rpc_id(1, "server_receive_input", global_position, rotation.y, velocity, is_crouching)

@rpc("any_peer", "call_remote", "unreliable")
func server_receive_input(pos: Vector3, rot_y: float, vel: Vector3, crouching: bool):
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var owner_id = get_multiplayer_authority()
	
	if sender_id != owner_id:
		return
	
	if server_crouching != crouching:
		print("🔍 SERVER: ", name, " crouch changed to ", crouching)
	
	server_position = pos
	server_rotation = rot_y
	server_velocity = vel
	server_crouching = crouching
	
	global_position = pos
	rotation.y = rot_y
	velocity = vel
	
	var all_peers = multiplayer.get_peers()
	
	for peer_id in all_peers:
		if peer_id != owner_id:
			if peer_id in multiplayer.get_peers():
				rpc_id(peer_id, "client_receive_state", pos, rot_y, vel, crouching)

@rpc("any_peer", "call_remote", "unreliable")
func client_receive_state(pos: Vector3, rot_y: float, vel: Vector3, crouching: bool):
	if multiplayer.get_remote_sender_id() != 1:
		return
	
	if is_multiplayer_authority():
		return
	
	if remote_crouching != crouching:
		print("🔍 CLIENT: ", name, " remote crouch changed to ", crouching)
	
	remote_position = pos
	remote_rotation = rot_y
	remote_crouching = crouching

func shoot() -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	
	# Play shoot sound
	play_shoot_sound()
	
	if gun_animator and gun_animator.has_animation("f_ak47_template_skeleton|shoot"):
		gun_animator.stop()
		gun_animator.play("f_ak47_template_skeleton|shoot")
		print("🔫 Playing shooting animation")
	
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
				var shooter_peer_id = get_peer_id()
				rpc_id(1, "server_process_hit", target_peer_id, shooter_peer_id)

@rpc("any_peer", "call_remote")
func server_process_hit(target_peer_id: int, shooter_peer_id: int):
	if not multiplayer.is_server():
		return
	
	var target = _find_player_by_peer_id(target_peer_id)
	var shooter = _find_player_by_peer_id(shooter_peer_id)
	
	if not target or target.is_dead:
		return
	
	if not shooter:
		print("⚠️ Shooter not found for peer ", shooter_peer_id)
		return
	
	print("💥 Hit confirmed: ", shooter.player_name, " -> ", target.player_name)
	target.server_apply_damage(100, shooter.player_name, shooter.team)
	
	# Notify shooter they got a kill
	rpc_id(shooter_peer_id, "client_on_kill")

@rpc("any_peer", "call_remote")
func client_on_kill():
	"""Called when this player gets a kill"""
	if not is_multiplayer_authority():
		return
	
	print("🎯 Kill confirmed!")
	play_kill_sound()

func _find_player_by_peer_id(peer_id: int) -> Player:
	for node in get_tree().get_nodes_in_group("players"):
		if node is Player and node.get_multiplayer_authority() == peer_id:
			return node
	return null

func server_apply_damage(amount: int, killer_name: String = "", killer_team: String = ""):
	if not multiplayer.is_server() or is_dead:
		return
	
	health -= amount
	print("💔 ", player_name, " took ", amount, " damage. HP: ", health)
	
	rpc_id(get_multiplayer_authority(), "client_sync_health", health)
	
	if health <= 0:
		server_kill_player(killer_name, killer_team)

@rpc("any_peer", "call_local")
func client_sync_health(new_health: int):
	health = new_health

func server_kill_player(killer_name: String = "", killer_team: String = ""):
	if not multiplayer.is_server() or is_dead:
		return
	
	is_dead = true
	velocity = Vector3.ZERO
	
	print("☠️ ", player_name, " (", team, ") killed by ", killer_name, " (", killer_team, ")")
	
	rpc("client_player_died")
	
	GameState.on_player_died(team, player_name, killer_team, killer_name)

@rpc("any_peer", "call_local")
func client_player_died():
	if multiplayer.get_remote_sender_id() != 1 and not multiplayer.is_server():
		return
	
	is_dead = true
	velocity = Vector3.ZERO
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	if is_multiplayer_authority():
		set_process_input(false)
		set_process_unhandled_input(false)

func is_player_dead() -> bool:
	return is_dead

@rpc("any_peer", "call_local", "reliable")
func force_respawn(spawn_pos: Vector3):
	if multiplayer.get_remote_sender_id() != 1 and not multiplayer.is_server():
		return
	
	is_dead = false
	health = 100
	global_position = spawn_pos
	velocity = Vector3.ZERO
	
	remote_position = spawn_pos
	server_position = spawn_pos
	
	camera_rotation = Vector2.ZERO
	rotation.y = 0
	if has_node("Camera3D"):
		$Camera3D.rotation.x = 0
	
	is_crouching = false
	is_jumping = false
	was_on_ground = true
	remote_crouching = false
	
	if is_multiplayer_authority():
		apply_crouch_visual(false)
	elif collision_shape and collision_shape.shape is CapsuleShape3D:
		collision_shape.shape.height = standing_height
	
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	if is_multiplayer_authority():
		set_process_input(true)
		set_process_unhandled_input(true)

func get_jump_stats() -> Dictionary:
	"""Get current jump statistics"""
	return {
		"speed": current_speed,
		"best_distance": best_jump_distance,
		"best_strafes": best_jump_strafes
	}

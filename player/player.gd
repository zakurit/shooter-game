extends CharacterBody3D
class_name Player

@export var speed: float = 6.0
var team: String = ""
var health: int = 100

func _ready() -> void:
	add_to_group("players")
	if not OS.has_feature("server"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var dir := Vector3.ZERO
		dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		dir.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")

		if dir.length() > 0.001:
			dir = dir.normalized()

		var move_vec := (global_transform.basis * dir)
		velocity.x = move_vec.x * speed
		velocity.z = move_vec.z * speed
		move_and_slide()

func shoot() -> void:
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
		if collider.is_in_group("players"):
			# Send damage request TO SERVER
			rpc_id(1, "server_apply_damage", collider.get_path(), 20)

@rpc("any_peer")
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		GameState.on_player_died(team)

@rpc("authority")
func server_apply_damage(target_path: NodePath, amount: int) -> void:
	var target := get_node_or_null(target_path)
	if target:
		# Apply damage on server instance
		target.take_damage(amount)
		# Notify clients visually (optional)
		target.rpc("take_damage", amount)

func respawn() -> void:
	health = 100
	global_position = GameState.random_spawn(team)

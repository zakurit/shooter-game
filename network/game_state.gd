extends Node

var red_score: int = 0
var blue_score: int = 0
var round_time_left: float = 60.0
var round_active: bool = false
var round_start_countdown: float = 5.0
var is_countdown_active: bool = false

# Track team counts (alive players)
var red_team_count: int = 0
var blue_team_count: int = 0

# Track total team sizes (doesn't decrease on death)
var red_team_size: int = 0
var blue_team_size: int = 0

# Spawn points (populated by map_loader.gd)
var red_spawns: Array = []
var blue_spawns: Array = []

signal round_started
signal round_ended
signal countdown_tick(seconds: int)

func _process(delta):
	if multiplayer.is_server():
		# Pre-round countdown
		if is_countdown_active:
			round_start_countdown -= delta
			if round_start_countdown <= 0:
				is_countdown_active = false
				start_round()
			else:
				var secs = int(ceil(round_start_countdown))
				rpc("update_countdown", secs)
		
		# Round timer
		elif round_active:
			round_time_left -= delta
			rpc("update_round_time", round_time_left)
			if round_time_left <= 0:
				end_round()

func assign_team(peer_id: int) -> String:
	# Balance teams: assign to team with fewer players
	var team: String
	
	if red_team_size < blue_team_size:
		team = "red"
		red_team_size += 1
		red_team_count += 1
	elif blue_team_size < red_team_size:
		team = "blue"
		blue_team_size += 1
		blue_team_count += 1
	else:
		# Equal counts - random
		team = "red" if randf() < 0.5 else "blue"
		if team == "red":
			red_team_size += 1
			red_team_count += 1
		else:
			blue_team_size += 1
			blue_team_count += 1
	
	print("Assigned peer ", peer_id, " to team: ", team, " (Red: ", red_team_size, ", Blue: ", blue_team_size, ")")
	return team

func on_player_died(team: String):
	if multiplayer.is_server():
		# Decrease alive count
		if team == "red":
			red_team_count = max(0, red_team_count - 1)
		else:
			blue_team_count = max(0, blue_team_count - 1)
		
		print("💀 Player died. Alive: Red: ", red_team_count, "/", red_team_size, " Blue: ", blue_team_count, "/", blue_team_size)
		
		# Check if a team is eliminated
		if red_team_count == 0:
			print("🏆 BLUE TEAM ELIMINATED RED TEAM!")
			team_eliminated("blue")
		elif blue_team_count == 0:
			print("🏆 RED TEAM ELIMINATED BLUE TEAM!")
			team_eliminated("red")

func team_eliminated(winning_team: String):
	if not multiplayer.is_server():
		return
	
	print("🎉 ", winning_team.to_upper(), " TEAM WINS!")
	
	# Award point to winning team
	if winning_team == "red":
		red_score += 1
	else:
		blue_score += 1
	
	rpc("update_scores", red_score, blue_score)
	
	# Wait 2 seconds for dramatic effect
	await get_tree().create_timer(2.0).timeout
	
	# Respawn ALL players
	respawn_all_players()
	
	# Reset alive counts to full team sizes
	red_team_count = red_team_size
	blue_team_count = blue_team_size
	
	print("🔄 Teams reset. Ready for next round!")

func random_spawn(team: String) -> Vector3:
	# Use spawn points from map if available
	if team == "red" and red_spawns.size() > 0:
		var spawn = red_spawns[randi() % red_spawns.size()]
		return spawn.global_position if spawn is Node3D else Vector3(-10, 1, 0)
	elif team == "blue" and blue_spawns.size() > 0:
		var spawn = blue_spawns[randi() % blue_spawns.size()]
		return spawn.global_position if spawn is Node3D else Vector3(10, 1, 0)
	
	# Fallback if no spawn points defined in map
	var spawn_area: Vector3
	if team == "red":
		spawn_area = Vector3(-10, 1, 0)
	else:
		spawn_area = Vector3(10, 1, 0)
	
	# Add random offset
	spawn_area.x += randf_range(-3, 3)
	spawn_area.z += randf_range(-3, 3)
	return spawn_area

@rpc("authority", "call_local")
func update_countdown(seconds: int):
	countdown_tick.emit(seconds)

@rpc("authority", "call_local")
func update_round_time(time: float):
	round_time_left = time

@rpc("authority", "call_local")
func update_scores(red: int, blue: int):
	red_score = red
	blue_score = blue

func start_countdown():
	if multiplayer.is_server():
		is_countdown_active = true
		round_start_countdown = 5.0
		rpc("update_countdown", 5)

func start_round():
	if multiplayer.is_server():
		round_active = true
		round_time_left = 60.0
		rpc("round_state_changed", true)
		round_started.emit()
		print("🎮 ROUND START! Red: ", red_team_size, " vs Blue: ", blue_team_size)

func end_round():
	if multiplayer.is_server():
		round_active = false
		rpc("round_state_changed", false)
		round_ended.emit()
		
		print("⏱️ Round ended by timer! Red: ", red_score, " Blue: ", blue_score)
		
		# Wait 3 seconds, then respawn everyone
		await get_tree().create_timer(3.0).timeout
		respawn_all_players()
		
		# Reset alive counts
		red_team_count = red_team_size
		blue_team_count = blue_team_size
		
		# Wait 2 more seconds, then start countdown for next round
		await get_tree().create_timer(2.0).timeout
		start_countdown()

func respawn_all_players():
	if multiplayer.is_server():
		print("🔄 Respawning all players...")
		var players = get_tree().get_nodes_in_group("players")
		print("   Found ", players.size(), " players")
		for player in players:
			if player is Player:
				var spawn_pos = random_spawn(player.team)
				print("   Respawning ", player.name, " (", player.team, ") at ", spawn_pos)
				player.force_respawn(spawn_pos)  # Call on server
				player.rpc_id(player.get_multiplayer_authority(), "force_respawn", spawn_pos)  # Call on client

@rpc("authority", "call_local")
func round_state_changed(active: bool):
	round_active = active
	if active:
		round_started.emit()
	else:
		round_ended.emit()

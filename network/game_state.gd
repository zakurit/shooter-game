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

# Track total team sizes
var red_team_size: int = 0
var blue_team_size: int = 0

# Prevent multiple respawn calls
var is_respawning: bool = false

# Spawn points
var red_spawns: Array = []
var blue_spawns: Array = []

signal round_started
signal round_ended
signal countdown_tick(seconds: int)
signal player_killed(killer_team: String, victim_team: String)

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
				end_round_timeout()

func assign_team(peer_id: int) -> String:
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
	if not multiplayer.is_server():
		return
	
	if is_respawning:
		print("⚠️ Already respawning, ignoring death")
		return
	
	# Decrease alive count
	if team == "red":
		red_team_count = max(0, red_team_count - 1)
	else:
		blue_team_count = max(0, blue_team_count - 1)
	
	print("💀 Player died. Alive: Red: ", red_team_count, "/", red_team_size, " Blue: ", blue_team_count, "/", blue_team_size)
	
	# Emit kill feed signal
	var killer_team = "blue" if team == "red" else "red"
	player_killed.emit(killer_team, team)
	rpc("sync_kill_feed", killer_team, team)
	
	# Check if a team is eliminated
	if red_team_count == 0 and blue_team_count > 0:
		print("🏆 BLUE TEAM WINS!")
		team_eliminated("blue")
	elif blue_team_count == 0 and red_team_count > 0:
		print("🏆 RED TEAM WINS!")
		team_eliminated("red")

func team_eliminated(winning_team: String):
	if not multiplayer.is_server():
		return
	
	if is_respawning:
		print("⚠️ Already handling team elimination")
		return
	
	is_respawning = true
	round_active = false  # Pause round
	
	# Award point
	if winning_team == "red":
		red_score += 1
	else:
		blue_score += 1
	
	rpc("update_scores", red_score, blue_score)
	print("📊 Score: Red ", red_score, " - Blue ", blue_score)
	
	# Small delay before respawn
	await get_tree().create_timer(2.0).timeout
	
	respawn_all_players()
	
	# Reset alive counts
	red_team_count = red_team_size
	blue_team_count = blue_team_size
	
	# Reset round timer and restart
	round_time_left = 60.0
	rpc("update_round_time", round_time_left)
	round_active = true
	
	is_respawning = false
	print("✅ Round continues!")

@rpc("authority", "call_local")
func sync_kill_feed(killer_team: String, victim_team: String):
	player_killed.emit(killer_team, victim_team)

func random_spawn(team: String) -> Vector3:
	if team == "red" and red_spawns.size() > 0:
		var spawn = red_spawns[randi() % red_spawns.size()]
		return spawn.global_position if spawn is Node3D else Vector3(-10, 1, 0)
	elif team == "blue" and blue_spawns.size() > 0:
		var spawn = blue_spawns[randi() % blue_spawns.size()]
		return spawn.global_position if spawn is Node3D else Vector3(10, 1, 0)
	
	var spawn_area: Vector3
	if team == "red":
		spawn_area = Vector3(-10, 1, 0)
	else:
		spawn_area = Vector3(10, 1, 0)
	
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
		print("🎮 ROUND START!")

func end_round_timeout():
	if multiplayer.is_server():
		round_active = false
		rpc("round_state_changed", false)
		round_ended.emit()
		
		print("⏱️ Round ended by timer!")
		
		await get_tree().create_timer(3.0).timeout
		respawn_all_players()
		
		red_team_count = red_team_size
		blue_team_count = blue_team_size
		
		await get_tree().create_timer(2.0).timeout
		start_countdown()

func respawn_all_players():
	if not multiplayer.is_server():
		return
	
	print("🔄 Respawning all players...")
	var players = get_tree().get_nodes_in_group("players")
	
	print("   Found ", players.size(), " players in group")
	
	for player in players:
		if player.has_method("force_respawn"):
			var spawn_pos = random_spawn(player.team)
			print("   ↻ Calling respawn on ", player.name, " (", player.team, ") at ", spawn_pos)
			# Call the RPC which has "call_local" so it runs on server AND clients
			player.rpc("force_respawn", spawn_pos)
		else:
			print("   ⚠️ Player ", player.name, " doesn't have force_respawn method!")
	
	print("✅ All respawn RPCs sent!")

@rpc("authority", "call_local")
func round_state_changed(active: bool):
	round_active = active
	if active:
		round_started.emit()
	else:
		round_ended.emit()

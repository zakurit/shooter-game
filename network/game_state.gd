extends Node

var scores := {
	"red": 0,
	"blue": 0
}

var red_spawns: Array = []
var blue_spawns: Array = []


func assign_team(peer_id: int) -> String:
	# Godot 4 ternary style:
	return "red" if peer_id % 2 == 0 else "blue"


func on_player_died(team: String):
	# Award point to opposite team
	if team == "red":
		scores["blue"] += 1
	else:
		scores["red"] += 1

	_restart_round()


func _restart_round():
	for p in get_tree().get_nodes_in_group("players"):
		p.respawn()


func random_spawn(team: String) -> Vector3:
	var arr: Array = red_spawns if team == "red" else blue_spawns

	if arr.is_empty():
		return Vector3.ZERO

	var index := randi() % arr.size()
	return arr[index].global_position

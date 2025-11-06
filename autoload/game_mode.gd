extends Node

# Set by main menu
var is_server: bool = false
var server_ip: String = "127.0.0.1"
var server_port: int = 7777
var player_nickname: String = "Player"

func reset():
	is_server = false
	server_ip = "127.0.0.1"
	server_port = 7777

func _ready():
	# Generate default nickname
	player_nickname = "Player" + str(randi() % 9999)

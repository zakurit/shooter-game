extends Node

# Set by main menu
var is_server: bool = false
var server_ip: String = "127.0.0.1"
var server_port: int = 7777

func reset():
	is_server = false
	server_ip = "127.0.0.1"
	server_port = 7777

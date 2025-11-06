extends Control

@onready var ip_input: LineEdit = $VBoxContainer/IpInput
@onready var port_input: LineEdit = $VBoxContainer/PortInput
@onready var nickname_input: LineEdit = $VBoxContainer/NicknameInput
@onready var connect_button: Button = $VBoxContainer/ConnectButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

# Runtime-only nickname storage
var player_nickname: String = "Player"

func _ready():
	if "-server" in OS.get_cmdline_args():
		get_tree().change_scene_to_file.call_deferred("res://game.tscn")
		return
	
	# Default values
	ip_input.text = "127.0.0.1"
	port_input.text = "7777"
	
	# Generate random nickname
	player_nickname = "Player" + str(randi() % 9999)
	nickname_input.text = player_nickname
	
	status_label.text = "Enter server IP and port to connect"
	
	# Connect signals
	connect_button.pressed.connect(_on_connect_pressed)
	nickname_input.text_changed.connect(_on_nickname_changed)
	
	# Show local IPs for convenience
	var local_ips = get_local_ips()
	if local_ips.size() > 0:
		status_label.text += "\n\nYour local IPs:\n" + "\n".join(local_ips)

func _on_nickname_changed(new_text: String):
	player_nickname = new_text.strip_edges()
	if player_nickname.is_empty():
		player_nickname = "Player"

func _on_connect_pressed():
	var ip := ip_input.text
	var port := int(port_input.text)
	
	if ip.is_empty() or port <= 0:
		status_label.text = "Invalid IP or Port!"
		return
	
	if player_nickname.strip_edges().is_empty():
		status_label.text = "Please enter a nickname!"
		return
	
	status_label.text = "Connecting to %s:%d..." % [ip, port]
	
	# Store connection info
	GameMode.is_server = false
	GameMode.server_ip = ip
	GameMode.server_port = port
	GameMode.player_nickname = player_nickname
	
	# Change to game scene
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://game.tscn")

func get_local_ips() -> Array[String]:
	var result: Array[String] = []
	var addresses := IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			result.append(addr)
	return result

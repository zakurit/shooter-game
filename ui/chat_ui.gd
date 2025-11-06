extends Control

@onready var chat_container: VBoxContainer = $ChatContainer
@onready var chat_log: RichTextLabel = $ChatContainer/ChatLog
@onready var input_container: HBoxContainer = $ChatContainer/InputContainer
@onready var chat_input: LineEdit = $ChatContainer/InputContainer/ChatInput

const MAX_MESSAGES = 50
var is_chat_open: bool = false

func _ready():
	# Hide input by default
	input_container.visible = false
	
	# Connect signals
	chat_input.text_submitted.connect(_on_chat_submitted)
	
	# Setup chat log
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	
	add_message("[color=gray]Press ENTER to open chat[/color]", "SYSTEM")

func _input(event):
	if event is InputEventKey and event.pressed:
		# Open chat with Enter (but not if already open)
		if event.keycode == KEY_ENTER and not is_chat_open:
			open_chat()
			get_viewport().set_input_as_handled()
		
		# Close chat with Escape
		elif event.keycode == KEY_ESCAPE and is_chat_open:
			close_chat()
			get_viewport().set_input_as_handled()

func open_chat():
	is_chat_open = true
	input_container.visible = true
	chat_input.grab_focus()
	
	# DON'T touch mouse mode - player script handles it
	
	# Disable player physics only
	var local_player = get_local_player()
	if local_player:
		local_player.set_physics_process(false)

func close_chat():
	is_chat_open = false
	input_container.visible = false
	chat_input.clear()
	chat_input.release_focus()
	
	# Re-enable player physics
	var local_player = get_local_player()
	if local_player:
		local_player.set_physics_process(true)

func _on_chat_submitted(text: String):
	if text.strip_edges().is_empty():
		close_chat()
		return
	
	send_message(text)
	chat_input.clear()
	close_chat()

func send_message(text: String):
	"""Send a chat message"""
	if not multiplayer or not multiplayer.multiplayer_peer:
		add_message("Not connected to server", "ERROR")
		return
	
	# Get local player
	var local_player = get_local_player()
	var sender_name = local_player.player_name if local_player else "Player"
	var team = local_player.team if local_player else "unknown"
	
	if multiplayer.is_server():
		# Server broadcasts to all (including self via call_local)
		rpc("client_receive_message", sender_name, team, text)
	else:
		# Client sends to server
		rpc_id(1, "server_receive_message", sender_name, team, text)

@rpc("any_peer", "call_remote", "reliable")
func server_receive_message(sender_name: String, team: String, text: String):
	"""Server receives and broadcasts messages"""
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	print("💬 Server received message from ", sender_name, ": ", text)
	
	# Broadcast to ALL clients (including the sender)
	rpc("client_receive_message", sender_name, team, text)

@rpc("any_peer", "call_local", "reliable")
func client_receive_message(sender_name: String, team: String, text: String):
	"""All clients receive and display message"""
	# Verify it's from server
	if multiplayer.get_remote_sender_id() != 1 and not multiplayer.is_server():
		print("⚠️ Ignoring chat message not from server")
		return
	
	print("💬 Displaying message from ", sender_name, ": ", text)
	display_message(sender_name, team, text)

func display_message(sender_name: String, team: String, text: String):
	"""Display a chat message"""
	var color = "white"
	if team == "red":
		color = "#ff6b6b"
	elif team == "blue":
		color = "#4dabf7"
	
	var formatted = "[color=%s]%s[/color]: %s" % [color, sender_name, text]
	add_message(formatted, "CHAT")

func add_message(text: String, tag: String = ""):
	"""Add a message to the chat log"""
	var timestamp = Time.get_time_string_from_system()
	var prefix = ""
	
	if tag == "SYSTEM":
		prefix = "[color=gray][%s][/color] " % timestamp
	elif tag == "ERROR":
		prefix = "[color=red][ERROR][/color] "
	else:
		prefix = "[color=gray][%s][/color] " % timestamp
	
	chat_log.append_text(prefix + text + "\n")
	
	# Limit message count
	var line_count = chat_log.get_line_count()
	if line_count > MAX_MESSAGES:
		# Remove oldest lines (this is approximate, RichTextLabel doesn't have perfect line removal)
		pass

func get_local_player():
	"""Find the local player"""
	for node in get_tree().get_nodes_in_group("players"):
		if node.has_method("is_multiplayer_authority") and node.is_multiplayer_authority():
			return node
	return null

# Helper to add system messages
func add_system_message(text: String):
	add_message("[color=yellow]" + text + "[/color]", "SYSTEM")

func add_kill_feed(killer_name: String, killer_team: String, victim_name: String, victim_team: String):
	"""Display kill feed"""
	var killer_color = "#ff6b6b" if killer_team == "red" else "#4dabf7"
	var victim_color = "#ff6b6b" if victim_team == "red" else "#4dabf7"
	
	var message = "[color=%s]%s[/color] [color=gray]killed[/color] [color=%s]%s[/color]" % [
		killer_color, killer_name, victim_color, victim_name
	]
	add_message(message, "KILL")

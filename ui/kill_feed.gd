extends Control

@onready var feed_container: VBoxContainer = $VBoxContainer

func _ready():
	# NEW: Updated signal connection with player names
	GameState.player_killed.connect(_on_player_killed)

# NEW: Updated signature to receive player names
func _on_player_killed(killer_name: String, victim_name: String, killer_team: String, victim_team: String):
	# Create container for colored text
	var hbox = HBoxContainer.new()
	
	# Killer name label (colored by killer's team)
	var killer_label = Label.new()
	killer_label.text = killer_name
	if killer_team == "red":
		killer_label.modulate = Color.RED
	elif killer_team == "blue":
		killer_label.modulate = Color.BLUE
	else:
		killer_label.modulate = Color.WHITE
	
	# "killed" text (neutral white)
	var action_label = Label.new()
	action_label.text = " killed "
	action_label.modulate = Color.WHITE
	
	# Victim name label (colored by victim's team)
	var victim_label = Label.new()
	victim_label.text = victim_name
	if victim_team == "red":
		victim_label.modulate = Color.RED
	elif victim_team == "blue":
		victim_label.modulate = Color.BLUE
	else:
		victim_label.modulate = Color.WHITE
	
	# Assemble the kill feed entry
	hbox.add_child(killer_label)
	hbox.add_child(action_label)
	hbox.add_child(victim_label)
	
	feed_container.add_child(hbox)
	
	# Remove after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(hbox):
		hbox.queue_free()

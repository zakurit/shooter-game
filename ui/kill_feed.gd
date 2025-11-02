extends Control

@onready var feed_container: VBoxContainer = $VBoxContainer

func _ready():
	GameState.player_killed.connect(_on_player_killed)

func _on_player_killed(killer_team: String, victim_team: String):
	var label = Label.new()
	label.text = "%s killed %s" % [killer_team.to_upper(), victim_team.to_upper()]
	
	# Simple color based on teams
	if killer_team == "red":
		label.modulate = Color.RED
	else:
		label.modulate = Color.BLUE
	
	feed_container.add_child(label)
	
	# Remove after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(label):
		label.queue_free()

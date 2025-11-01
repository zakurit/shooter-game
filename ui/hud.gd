extends Control

@onready var crosshair: TextureRect = $Crosshair as TextureRect
@onready var fps_label: Label = $FpsLabel
@onready var pos_label: Label = $PosLabel
@onready var score_label: Label = $ScoreLabel
@onready var timer_label: Label = $TimerLabel

var local_player: Player = null

func _ready():
	# Create crosshair if not in scene or wrong type
	if not has_node("Crosshair") or not ($Crosshair is TextureRect):
		if has_node("Crosshair"):
			$Crosshair.queue_free()
		crosshair = TextureRect.new()
		crosshair.name = "Crosshair"
		crosshair.custom_minimum_size = Vector2(4, 4)
		crosshair.modulate = Color.WHITE
		crosshair.position = get_viewport().size * 0.5 - Vector2(2, 2)
		add_child(crosshair)
		# Draw a simple cross
		var cross = ColorRect.new()
		cross.size = Vector2(20, 2)
		cross.position = Vector2(-10, -1)
		crosshair.add_child(cross)
		var cross2 = ColorRect.new()
		cross2.size = Vector2(2, 20)
		cross2.position = Vector2(-1, -10)
		crosshair.add_child(cross2)
	else:
		crosshair = $Crosshair

func _process(delta):
	# Find local player
	if not local_player or not is_instance_valid(local_player):
		for player in get_tree().get_nodes_in_group("players"):
			if player.is_multiplayer_authority():
				local_player = player
				break
	
	# Update FPS
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	# Update position
	if local_player:
		pos_label.text = "Pos: %.1f, %.1f, %.1f" % [
			local_player.global_position.x,
			local_player.global_position.y,
			local_player.global_position.z
		]
	
	# Update scores - FIXED LINE
	score_label.text = "Red: %d | Blue: %d" % [GameState.red_score, GameState.blue_score]
	
	# Update timer
	if GameState.is_countdown_active:
		timer_label.text = "Round starts in: %d" % int(ceil(GameState.round_start_countdown))
	elif GameState.round_active:
		timer_label.text = "Time: %d" % int(ceil(GameState.round_time_left))
	else:
		timer_label.text = "Waiting..."

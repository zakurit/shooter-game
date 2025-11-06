extends Control

@onready var score_label: Label = $ScoreLabel
@onready var timer_label: Label = $TimerLabel
@onready var pos_label: Label = $VBoxContainer/PosLabel
@onready var fps_label: Label = $VBoxContainer/FpsLabel
@onready var velocity_label: Label = $VBoxContainer/VelocityLabel
@onready var forward_velocity_label: Label = $VBoxContainer/ForwardVelocityLabel
@onready var crosshair_container: Control = $Crosshair if has_node("Crosshair") else null

var local_player: Player = null
var pause_menu: Control = null

# Crosshair settings
var crosshair_thickness: int = 2
var crosshair_offset: int = 2
var crosshair_length: int = 10
var crosshair_color: Color = Color.WHITE

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set all UI to ignore mouse
	if score_label:
		score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if timer_label:
		timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("VBoxContainer"):
		$VBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if pos_label:
			pos_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if fps_label:
			fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if velocity_label:
			velocity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if forward_velocity_label:
			forward_velocity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if crosshair_container:
		crosshair_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Center the crosshair container on screen
		center_crosshair_container()
		print("✅ Found Crosshair container and centered it")
	else:
		print("❌ No Crosshair container in scene!")
	
	create_pause_menu()
	print("✅ HUD initialized")

func center_crosshair_container():
	"""Center the crosshair container on screen and keep it centered on resize"""
	if not crosshair_container:
		return
	
	# Set anchors to center
	crosshair_container.anchor_left = 0.5
	crosshair_container.anchor_right = 0.5
	crosshair_container.anchor_top = 0.5
	crosshair_container.anchor_bottom = 0.5
	
	# Reset offsets so it stays perfectly centered
	crosshair_container.offset_left = 0
	crosshair_container.offset_right = 0
	crosshair_container.offset_top = 0
	crosshair_container.offset_bottom = 0
	
	crosshair_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Make sure it's on top
	crosshair_container.z_index = 100
	
	print("📍 Crosshair container centered")
	print("   Position: ", crosshair_container.position)
	print("   Global Position: ", crosshair_container.global_position)
	print("   Size: ", crosshair_container.size)
	print("   Anchors: L=", crosshair_container.anchor_left, " R=", crosshair_container.anchor_right, 
		  " T=", crosshair_container.anchor_top, " B=", crosshair_container.anchor_bottom)
	print("   Z-Index: ", crosshair_container.z_index)

func create_pause_menu():
	var pause_script = load("res://ui/pause_menu.gd")
	pause_menu = Control.new()
	pause_menu.set_script(pause_script)
	pause_menu.name = "PauseMenu"
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_menu)
	
	# Wait for pause menu _ready() to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Set the callback
	if pause_menu.has_method("set_crosshair_callback"):
		pause_menu.set_crosshair_callback(_on_crosshair_changed)
		print("✅ Crosshair callback set!")
	else:
		print("❌ ERROR: pause_menu does not have set_crosshair_callback method!")
	
	# Load and apply initial settings to show default crosshair
	if pause_menu.has_method("get_crosshair_settings"):
		var settings = pause_menu.get_crosshair_settings()
		crosshair_thickness = settings.thickness
		crosshair_offset = settings.offset
		crosshair_length = settings.length
		crosshair_color = settings.color
		print("✅ Loaded settings: T=", crosshair_thickness, " O=", crosshair_offset, " L=", crosshair_length)
		
		# Build initial crosshair
		rebuild_crosshair()
	else:
		print("❌ ERROR: pause_menu does not have get_crosshair_settings method!")

func rebuild_crosshair():
	if not crosshair_container:
		print("⚠️ No crosshair container to rebuild!")
		return
	
	print("🔨 Rebuilding crosshair with T=", crosshair_thickness, " O=", crosshair_offset, " L=", crosshair_length, " C=", crosshair_color)
	
	# Clear ALL old children from CenterContainer
	for child in crosshair_container.get_children():
		print("   Removing old child: ", child.name)
		child.queue_free()
	
	# CenterContainer needs a single child Control to position things relative to
	var holder = Control.new()
	holder.name = "CrosshairLines"
	holder.custom_minimum_size = Vector2(100, 100)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_container.add_child(holder)
	
	print("   Created holder: ", holder.name, " Size: ", holder.size)
	
	var center = 50.0
	
	# Left line
	var left = ColorRect.new()
	left.name = "Left"
	left.color = crosshair_color
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.position = Vector2(center - crosshair_length - crosshair_offset, center - crosshair_thickness / 2.0)
	left.size = Vector2(crosshair_length, crosshair_thickness)
	holder.add_child(left)
	print("   Left line: pos=", left.position, " size=", left.size, " color=", left.color)
	
	# Right line
	var right = ColorRect.new()
	right.name = "Right"
	right.color = crosshair_color
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.position = Vector2(center + crosshair_offset, center - crosshair_thickness / 2.0)
	right.size = Vector2(crosshair_length, crosshair_thickness)
	holder.add_child(right)
	print("   Right line: pos=", right.position, " size=", right.size)
	
	# Top line
	var top = ColorRect.new()
	top.name = "Top"
	top.color = crosshair_color
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(center - crosshair_thickness / 2.0, center - crosshair_length - crosshair_offset)
	top.size = Vector2(crosshair_thickness, crosshair_length)
	holder.add_child(top)
	print("   Top line: pos=", top.position, " size=", top.size)
	
	# Bottom line
	var bottom = ColorRect.new()
	bottom.name = "Bottom"
	bottom.color = crosshair_color
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.position = Vector2(center - crosshair_thickness / 2.0, center + crosshair_offset)
	bottom.size = Vector2(crosshair_thickness, crosshair_length)
	holder.add_child(bottom)
	print("   Bottom line: pos=", bottom.position, " size=", bottom.size)
	
	print("✅ Crosshair rebuilt with ", holder.get_child_count(), " lines")
	print("   Holder global pos: ", holder.global_position)
	print("   Container visible: ", crosshair_container.visible)
	print("   Holder visible: ", holder.visible)

func _on_crosshair_changed(thickness: int, offset: int, length: int, color: Color):
	print("🔔 Crosshair changed! T=", thickness, " O=", offset, " L=", length, " C=", color)
	crosshair_thickness = thickness
	crosshair_offset = offset
	crosshair_length = length
	crosshair_color = color
	
	# Rebuild immediately (not async, so it updates right away)
	if not crosshair_container:
		return
	
	# Clear old children
	for child in crosshair_container.get_children():
		child.queue_free()
	
	# Create new holder with updated settings
	var holder = Control.new()
	holder.name = "CrosshairLines"
	holder.custom_minimum_size = Vector2(100, 100)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_container.add_child(holder)
	
	var center = 50.0
	
	# Build all 4 lines with new settings
	var left = ColorRect.new()
	left.color = crosshair_color
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.position = Vector2(center - crosshair_length - crosshair_offset, center - crosshair_thickness / 2.0)
	left.size = Vector2(crosshair_length, crosshair_thickness)
	holder.add_child(left)
	
	var right = ColorRect.new()
	right.color = crosshair_color
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.position = Vector2(center + crosshair_offset, center - crosshair_thickness / 2.0)
	right.size = Vector2(crosshair_length, crosshair_thickness)
	holder.add_child(right)
	
	var top = ColorRect.new()
	top.color = crosshair_color
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(center - crosshair_thickness / 2.0, center - crosshair_length - crosshair_offset)
	top.size = Vector2(crosshair_thickness, crosshair_length)
	holder.add_child(top)
	
	var bottom = ColorRect.new()
	bottom.color = crosshair_color
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.position = Vector2(center - crosshair_thickness / 2.0, center + crosshair_offset)
	bottom.size = Vector2(crosshair_thickness, crosshair_length)
	holder.add_child(bottom)
	
	print("✅ Crosshair updated live!")

func _process(delta):
	if not local_player or not is_instance_valid(local_player):
		for player in get_tree().get_nodes_in_group("players"):
			if player.is_multiplayer_authority():
				local_player = player
				break
	
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	if local_player:
		pos_label.text = "Pos: %.1f, %.1f, %.1f" % [
			local_player.global_position.x,
			local_player.global_position.y,
			local_player.global_position.z
		]
		
		velocity_label.text = "Vel: %.1f, %.1f, %.1f" % [
			local_player.velocity.x,
			local_player.velocity.y,
			local_player.velocity.z
		]
		
		var horizontal_vel = Vector2(local_player.velocity.x, local_player.velocity.z)
		var forward_speed = horizontal_vel.length()
		forward_velocity_label.text = "Speed: %.1f" % forward_speed
	
	score_label.text = "Red: %d | Blue: %d" % [GameState.red_score, GameState.blue_score]
	
	if GameState.is_countdown_active:
		timer_label.text = "Round starts in: %d" % int(ceil(GameState.round_start_countdown))
	elif GameState.round_active:
		timer_label.text = "Time: %d" % int(ceil(GameState.round_time_left))
	else:
		timer_label.text = "Waiting..."

func set_chat_open(open: bool):
	if pause_menu and pause_menu.has_method("set_chat_open"):
		pause_menu.set_chat_open(open)

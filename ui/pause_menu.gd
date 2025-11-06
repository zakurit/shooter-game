extends Control

var is_menu_open: bool = false
var chat_open: bool = false

# Crosshair settings
var crosshair_thickness: int = 2
var crosshair_offset: int = 2
var crosshair_length: int = 10
var crosshair_color: Color = Color.WHITE

# UI References
var main_menu: VBoxContainer
var options_menu: VBoxContainer
var preview_crosshair: Control

# Callback for crosshair changes (must be declared before _ready)
var crosshair_callback: Callable = Callable()

func set_crosshair_callback(callback: Callable):
	crosshair_callback = callback
	print("✅ Crosshair callback registered!")

func _ready():
	print("🔧 PauseMenu _ready() called")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	load_crosshair_settings()
	create_ui()

func create_ui():
	print("🎨 Creating UI...")
	
	# Dark overlay background
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Center everything
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	# Main container with padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(main_vbox)
	
	# === MAIN MENU ===
	main_menu = VBoxContainer.new()
	main_menu.add_theme_constant_override("separation", 15)
	main_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(main_menu)
	
	var title = Label.new()
	title.text = "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_menu.add_child(title)
	
	add_spacer(main_menu, 30)
	
	var resume_btn = create_button("Resume (ESC)", _on_resume_pressed)
	main_menu.add_child(resume_btn)
	
	var options_btn = create_button("Crosshair Settings", _on_options_pressed)
	main_menu.add_child(options_btn)
	
	var exit_btn = create_button("Exit to Desktop", _on_exit_pressed)
	main_menu.add_child(exit_btn)
	
	# === OPTIONS MENU ===
	options_menu = VBoxContainer.new()
	options_menu.add_theme_constant_override("separation", 10)
	options_menu.visible = false
	options_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(options_menu)
	
	var options_title = Label.new()
	options_title.text = "CROSSHAIR SETTINGS"
	options_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_title.add_theme_font_size_override("font_size", 36)
	options_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_menu.add_child(options_title)
	
	add_spacer(options_menu, 20)
	
	# Preview box
	preview_crosshair = Control.new()
	preview_crosshair.custom_minimum_size = Vector2(400, 200)
	preview_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_menu.add_child(preview_crosshair)
	
	var preview_bg = ColorRect.new()
	preview_bg.name = "Background"
	preview_bg.color = Color(0.15, 0.15, 0.15, 1.0)
	preview_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_crosshair.add_child(preview_bg)
	
	update_preview_crosshair()
	
	add_spacer(options_menu, 10)
	
	# Sliders
	create_slider("Thickness", crosshair_thickness, 1, 10, _on_thickness_changed, options_menu)
	create_slider("Gap", crosshair_offset, 0, 20, _on_offset_changed, options_menu)
	create_slider("Length", crosshair_length, 5, 30, _on_length_changed, options_menu)
	
	# Color picker
	var color_hbox = HBoxContainer.new()
	color_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_menu.add_child(color_hbox)
	
	var color_label = Label.new()
	color_label.text = "Color"
	color_label.custom_minimum_size = Vector2(100, 0)
	color_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_hbox.add_child(color_label)
	
	var color_picker = ColorPickerButton.new()
	color_picker.color = crosshair_color
	color_picker.custom_minimum_size = Vector2(200, 40)
	color_picker.color_changed.connect(_on_color_changed)
	color_hbox.add_child(color_picker)
	
	add_spacer(options_menu, 20)
	
	var back_btn = create_button("Back", _on_back_pressed)
	options_menu.add_child(back_btn)

func add_spacer(parent: Node, height: int):
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)

func create_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(350, 50)
	btn.pressed.connect(callback)
	return btn

func create_slider(label_text: String, default_value: float, min_val: float, max_val: float, callback: Callable, parent: Node):
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(100, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 1
	slider.value = default_value
	slider.custom_minimum_size = Vector2(200, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	hbox.add_child(slider)
	
	var value_label = Label.new()
	value_label.text = str(int(default_value))
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(value_label)
	
	slider.value_changed.connect(func(val): value_label.text = str(int(val)))

func update_preview_crosshair():
	if not preview_crosshair:
		return
	
	# Remove old crosshair lines (but keep the background)
	for child in preview_crosshair.get_children():
		if child.name != "Background":
			child.queue_free()
	
	# Left
	var left = ColorRect.new()
	left.name = "LineLeft"
	left.color = crosshair_color
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.position = Vector2(200 - crosshair_length - crosshair_offset, 100 - crosshair_thickness / 2.0)
	left.size = Vector2(crosshair_length, crosshair_thickness)
	preview_crosshair.add_child(left)
	
	# Right
	var right = ColorRect.new()
	right.name = "LineRight"
	right.color = crosshair_color
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.position = Vector2(200 + crosshair_offset, 100 - crosshair_thickness / 2.0)
	right.size = Vector2(crosshair_length, crosshair_thickness)
	preview_crosshair.add_child(right)
	
	# Top
	var top = ColorRect.new()
	top.name = "LineTop"
	top.color = crosshair_color
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(200 - crosshair_thickness / 2.0, 100 - crosshair_length - crosshair_offset)
	top.size = Vector2(crosshair_thickness, crosshair_length)
	preview_crosshair.add_child(top)
	
	# Bottom
	var bottom = ColorRect.new()
	bottom.name = "LineBottom"
	bottom.color = crosshair_color
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.position = Vector2(200 - crosshair_thickness / 2.0, 100 + crosshair_offset)
	bottom.size = Vector2(crosshair_thickness, crosshair_length)
	preview_crosshair.add_child(bottom)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("🎮 ESC pressed! chat_open=", chat_open, " is_menu_open=", is_menu_open)
		if not chat_open:
			toggle_menu()
			get_viewport().set_input_as_handled()

func toggle_menu():
	is_menu_open = !is_menu_open
	visible = is_menu_open
	
	if is_menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("📋 Menu OPENED")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("📋 Menu CLOSED")
		main_menu.visible = true
		options_menu.visible = false

func _on_resume_pressed():
	toggle_menu()

func _on_options_pressed():
	main_menu.visible = false
	options_menu.visible = true

func _on_back_pressed():
	options_menu.visible = false
	main_menu.visible = true

func _on_exit_pressed():
	print("👋 Exiting game...")
	get_tree().quit()

func _on_thickness_changed(value: float):
	crosshair_thickness = int(value)
	print("🔧 Thickness changed to: ", crosshair_thickness)
	update_crosshair()

func _on_offset_changed(value: float):
	crosshair_offset = int(value)
	print("🔧 Offset changed to: ", crosshair_offset)
	update_crosshair()

func _on_length_changed(value: float):
	crosshair_length = int(value)
	print("🔧 Length changed to: ", crosshair_length)
	update_crosshair()

func _on_color_changed(color: Color):
	crosshair_color = color
	print("🔧 Color changed to: ", crosshair_color)
	update_crosshair()

func update_crosshair():
	update_preview_crosshair()
	save_crosshair_settings()
	
	# Call the callback if it's set
	if crosshair_callback.is_valid():
		print("📡 Calling crosshair callback")
		crosshair_callback.call(crosshair_thickness, crosshair_offset, crosshair_length, crosshair_color)
	else:
		print("⚠️ Crosshair callback not set!")

func save_crosshair_settings():
	var exe_dir = OS.get_executable_path().get_base_dir()
	var save_path = exe_dir + "/crosshair_settings.cfg"
	
	var config = ConfigFile.new()
	config.set_value("crosshair", "thickness", crosshair_thickness)
	config.set_value("crosshair", "offset", crosshair_offset)
	config.set_value("crosshair", "length", crosshair_length)
	config.set_value("crosshair", "color", crosshair_color)
	var err = config.save(save_path)
	if err == OK:
		print("💾 Settings saved")
	else:
		print("⚠️ Failed to save: ", err)

func load_crosshair_settings():
	var exe_dir = OS.get_executable_path().get_base_dir()
	var save_path = exe_dir + "/crosshair_settings.cfg"
	
	var config = ConfigFile.new()
	var err = config.load(save_path)
	if err == OK:
		crosshair_thickness = config.get_value("crosshair", "thickness", 2)
		crosshair_offset = config.get_value("crosshair", "offset", 2)
		crosshair_length = config.get_value("crosshair", "length", 10)
		crosshair_color = config.get_value("crosshair", "color", Color.WHITE)
		print("✅ Settings loaded")
	else:
		print("ℹ️ No saved settings, using defaults")

func set_chat_open(open: bool):
	chat_open = open
	print("💬 Chat open: ", open)

func get_crosshair_settings() -> Dictionary:
	return {
		"thickness": crosshair_thickness,
		"offset": crosshair_offset,
		"length": crosshair_length,
		"color": crosshair_color
	}

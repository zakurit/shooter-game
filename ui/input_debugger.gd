extends Node

func _ready():
	print("🔍 InputDebugger started - monitoring ALL input")

func _input(event):
	# This runs FIRST for ALL input events in the entire game
	if event is InputEventMouseMotion:
		var viewport = get_viewport()
		var focused_control = viewport.gui_get_focus_owner()
		
		print("\n🌍 GLOBAL _input() MouseMotion:")
		print("   Relative: ", event.relative)
		print("   Mouse Mode: ", Input.mouse_mode)
		print("   Focused Control: ", focused_control)
		
		if focused_control:
			print("   ⚠️ CONTROL HAS FOCUS: ", focused_control.name, " (", focused_control.get_class(), ")")
			print("   Control mouse filter: ", focused_control.mouse_filter)
		
		# Check for ANY Control nodes under the mouse
		var mouse_pos = event.position
		var controls_at_pos = _find_controls_at_position(get_tree().root, mouse_pos)
		if controls_at_pos.size() > 0:
			print("   ⚠️ Controls at mouse position:")
			for ctrl in controls_at_pos:
				print("      - ", ctrl.name, " (", ctrl.get_class(), ") | Filter: ", ctrl.mouse_filter)
		
		if viewport.is_input_handled():
			print("   ❌ INPUT ALREADY HANDLED!")
			_print_call_stack()

func _find_controls_at_position(node: Node, pos: Vector2, found: Array = []) -> Array:
	if node is Control:
		var ctrl = node as Control
		if ctrl.visible and ctrl.get_global_rect().has_point(pos):
			if ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				found.append(ctrl)
	
	for child in node.get_children():
		_find_controls_at_position(child, pos, found)
	
	return found

func _print_call_stack():
	print("   📚 Call stack:")
	var stack = get_stack()
	for i in range(min(5, stack.size())):
		var frame = stack[i]
		print("      ", i, ": ", frame["source"], ":", frame["line"], " in ", frame["function"])

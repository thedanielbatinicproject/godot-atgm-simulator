extends Node

class_name UICursorController

## Reusable joystick/mouse cursor controller for UI menus.
## Handles cursor switching, virtual mouse movement, and click simulation.
## Based on MainMenu implementation.

# Cursor textures - preload defaults
var joystick_cursor: Texture2D = preload("res://assets/UI/Cursors/CursorJoystick.png")
var default_cursor: Texture2D = preload("res://assets/UI/Cursors/CursorMouseAndKeyboardSmall.png")

# State tracking
var using_joystick := false
var floating_cursor_speed := 900.0  # pixels per second
var joystick_deadzone := 0.15
var last_mouse_time := 0.0
var last_joystick_time := 0.0

# Whether to hide cursor completely (for loading screens)
var hide_cursor_completely := false

# Reference to parent Control (for viewport access)
var _parent: Control = null


func setup(parent: Control, hide_cursor: bool = false) -> void:
	"""Initialize the cursor controller with a parent Control node."""
	_parent = parent
	hide_cursor_completely = hide_cursor
	
	if hide_cursor_completely:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if default_cursor:
			Input.set_custom_mouse_cursor(default_cursor)


func handle_input(event: InputEvent) -> void:
	"""Call this from _input() in the parent script."""
	if hide_cursor_completely:
		return  # No cursor handling needed
	
	# --- Mouse input ---
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# Ignore mouse events triggered by warp_mouse (within 0.1s of joystick use)
		if current_time - last_joystick_time < 0.1:
			return
		
		last_mouse_time = current_time
		
		if using_joystick:
			using_joystick = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if default_cursor:
				Input.set_custom_mouse_cursor(default_cursor)
	
	# --- Gamepad input ---
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		# Read virtual stick from InputMap
		var x := Input.get_action_strength("ui_point_right") - Input.get_action_strength("ui_point_left")
		var y := Input.get_action_strength("ui_point_down") - Input.get_action_strength("ui_point_up")
		var mag := Vector2(x, y).length()
		
		# Prevent noise from tiny axis jitter
		if mag > joystick_deadzone or event is InputEventJoypadButton:
			last_joystick_time = Time.get_ticks_msec() / 1000.0
			
			if not using_joystick:
				using_joystick = true
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				if joystick_cursor:
					Input.set_custom_mouse_cursor(joystick_cursor)


func process(delta: float) -> void:
	"""Call this from _process() in the parent script."""
	if hide_cursor_completely or not _parent:
		return
	
	if not using_joystick:
		return
	
	var x := Input.get_action_strength("ui_point_right") - Input.get_action_strength("ui_point_left")
	var y := Input.get_action_strength("ui_point_down") - Input.get_action_strength("ui_point_up")
	var move := Vector2(x, y)
	
	# --- Virtual mouse movement ---
	if move.length() > joystick_deadzone:
		# Update timestamp so system knows joystick is driving cursor
		last_joystick_time = Time.get_ticks_msec() / 1000.0
		
		var viewport := _parent.get_viewport()
		var rect := viewport.get_visible_rect()
		var mouse_pos := viewport.get_mouse_position()
		
		# Analog speed preserved (no normalize)
		var new_pos := mouse_pos + move * floating_cursor_speed * delta
		new_pos.x = clamp(new_pos.x, 0.0, rect.size.x)
		new_pos.y = clamp(new_pos.y, 0.0, rect.size.y)
		
		Input.warp_mouse(new_pos)
	
	# --- Gamepad "select" → left click ---
	if Input.is_action_just_pressed("select"):
		_simulate_click()


func _simulate_click() -> void:
	"""Simulate a mouse left-click at current cursor position."""
	if not _parent:
		return
	
	var pos := _parent.get_viewport().get_mouse_position()
	
	var press := InputEventMouseButton.new()
	press.position = pos
	press.global_position = pos
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	_parent.get_viewport().push_input(press)
	
	var release := InputEventMouseButton.new()
	release.position = pos
	release.global_position = pos
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.button_mask = MOUSE_BUTTON_MASK_LEFT
	_parent.get_viewport().push_input(release)


func cleanup() -> void:
	"""Call when the UI is being hidden/destroyed to restore cursor state."""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if default_cursor:
		Input.set_custom_mouse_cursor(default_cursor)

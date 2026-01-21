extends Control

## Menu controller with joystick/mouse cursor support.
## Used for PauseMenu, MissionSuccessfulScreen, MissionFailureScreen.

# Cursor textures
var joystick_cursor: Texture2D = preload("res://assets/UI/Cursors/CursorJoystick.png")
var default_cursor: Texture2D = preload("res://assets/UI/Cursors/CursorMouseAndKeyboardSmall.png")

# State tracking
var using_joystick := false
var floating_cursor_speed := 900.0  # pixels per second
var joystick_deadzone := 0.15
var last_mouse_time := 0.0
var last_joystick_time := 0.0


func _ready() -> void:
	# Show cursor and set default
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if default_cursor:
		Input.set_custom_mouse_cursor(default_cursor)


func _input(event: InputEvent) -> void:
	# Only process when visible
	if not visible:
		return
	
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


func _process(delta: float) -> void:
	# Only process when visible
	if not visible:
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
		
		var viewport := get_viewport()
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
	var pos := get_viewport().get_mouse_position()
	
	var press := InputEventMouseButton.new()
	press.position = pos
	press.global_position = pos
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(press)
	
	var release := InputEventMouseButton.new()
	release.position = pos
	release.global_position = pos
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(release)

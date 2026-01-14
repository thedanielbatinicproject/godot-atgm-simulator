extends Control

@onready var options: Control = $"Options"
@onready var main_menu: VBoxContainer = $"MainMenuRoot"
@onready var scenario_selector: Control = $ScenarioSelector
@onready var main_menu_music: AudioStreamPlayer = $MainMenuMusic


# --- CURSOR SWITCHING ---
@export var joystick_cursor: Texture2D
@export var default_cursor: Texture2D
@onready var floating_cursor: TextureRect = $FloatingCursor if has_node("FloatingCursor") else null
var using_joystick := false
var floating_cursor_speed := 900.0 # pixels per second
var joystick_deadzone := 0.15
var last_mouse_time := 0.0
var last_joystick_time := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if floating_cursor:
		floating_cursor.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		last_mouse_time = Time.get_ticks_msec() / 1000.0

		if using_joystick:
			using_joystick = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

			if default_cursor:
				Input.set_custom_mouse_cursor(default_cursor)

	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		# Only switch to joystick UI if input exceeds deadzone
		var x := Input.get_action_strength("ui_point_right") - Input.get_action_strength("ui_point_left")
		var y := Input.get_action_strength("ui_point_down") - Input.get_action_strength("ui_point_up")
		var mag := Vector2(x, y).length()

		if mag > joystick_deadzone:
			last_joystick_time = Time.get_ticks_msec() / 1000.0

			if not using_joystick:
				using_joystick = true
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

				if joystick_cursor:
					Input.set_custom_mouse_cursor(joystick_cursor)


func _process(delta):
	# Switch to mouse UI if mouse was used recently
	if using_joystick and (Time.get_ticks_msec() / 1000.0 - last_mouse_time < 0.2):
		using_joystick = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if default_cursor:
			Input.set_custom_mouse_cursor(default_cursor)

	# Joystick movement
	var x = Input.get_action_strength("ui_point_right") - Input.get_action_strength("ui_point_left")
	var y = Input.get_action_strength("ui_point_down") - Input.get_action_strength("ui_point_up")
	var mag = Vector2(x, y).length()
	if mag > joystick_deadzone:
		last_joystick_time = Time.get_ticks_msec() / 1000.0
		if not using_joystick:
			using_joystick = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if joystick_cursor:
				Input.set_custom_mouse_cursor(joystick_cursor)

	if using_joystick:
		# Move the system cursor with joystick
		var move := Vector2(x, y)
		if move.length() > joystick_deadzone:
			var viewport := get_viewport()
			var rect := viewport.get_visible_rect()
			var mouse_pos := viewport.get_mouse_position()
			var new_pos := mouse_pos + move.normalized() * floating_cursor_speed * delta
			new_pos.x = clamp(new_pos.x, 0, rect.size.x)
			new_pos.y = clamp(new_pos.y, 0, rect.size.y)
			Input.warp_mouse(new_pos)

		# Joystick select emulates LMB click at system cursor
		if Input.is_action_just_pressed("select"):
			var mouse_button := InputEventMouseButton.new()
			mouse_button.position = Input.get_last_mouse_position()
			mouse_button.global_position = Input.get_last_mouse_position()
			mouse_button.button_index = MOUSE_BUTTON_LEFT
			mouse_button.pressed = true
			mouse_button.button_mask = MOUSE_BUTTON_MASK_LEFT
			get_viewport().push_input(mouse_button)
			# Release event
			var mouse_button_release := InputEventMouseButton.new()
			mouse_button_release.position = Input.get_last_mouse_position()
			mouse_button_release.global_position = Input.get_last_mouse_position()
			mouse_button_release.button_index = MOUSE_BUTTON_LEFT
			mouse_button_release.pressed = false
			mouse_button_release.button_mask = MOUSE_BUTTON_MASK_LEFT
			get_viewport().push_input(mouse_button_release)


func _on_exit_btn_pressed() -> void:
	get_tree().quit()


func _on_option_btn_pressed() -> void:
	main_menu.visible = false
	options.visible = true

func _on_start_btn_pressed() -> void:
	main_menu.visible = false
	scenario_selector.visible = true


func _on_main_menu_music_finished() -> void:
	main_menu_music.play()

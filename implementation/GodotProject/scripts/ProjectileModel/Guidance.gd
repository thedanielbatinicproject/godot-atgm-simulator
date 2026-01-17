extends Node
class_name Guidance

# REFERENCE
var input_manager: InputManager
var game_profile: GameProfileData

# UPRAVLJAČKI ULAZI
var throttle_input: float = 0.0
var gimbal_x_input: float = 0.0
var gimbal_y_input: float = 0.0
var roll_input: float = 0.0  # -1 = roll left, +1 = roll right

# INICIJALIZACIJA

func _init(p_game_profile: GameProfileData = null):
	game_profile = p_game_profile
	reset_inputs()

func _ready():
	# Pokušaj pronaći InputManager u sceni
	# Use call_deferred to allow InputManager to be added first
	call_deferred("_find_input_manager")


func _find_input_manager():
	"""Pronađi InputManager u sceni i poveži signale."""
	# Traži u root-u scene
	var root = get_tree().root
	input_manager = _find_node_by_class(root, "InputManager")
	
	if input_manager:
		input_manager.input_state_changed.connect(_on_input_state_changed)
		print("[Guidance] Connected to InputManager")
	else:
		# Retry after a short delay - InputManager might be added later
		push_warning("[Guidance] InputManager not found, retrying in 0.1s...")
		await get_tree().create_timer(0.1).timeout
		_retry_find_input_manager()


func _retry_find_input_manager():
	"""Retry finding InputManager after delay."""
	var root = get_tree().root
	input_manager = _find_node_by_class(root, "InputManager")
	
	if input_manager:
		input_manager.input_state_changed.connect(_on_input_state_changed)
		print("[Guidance] Connected to InputManager (retry successful)")
	else:
		push_error("[Guidance] InputManager not found after retry!")

func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	"""Rekurzivno traži node po class_name."""
	if node.get_script() and node.get_script().get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var found = _find_node_by_class(child, class_name_str)
		if found:
			return found
	return null

func _on_input_state_changed(state: Vector3):
	"""Callback kada se input promijeni."""
	throttle_input = state.x
	gimbal_x_input = state.y
	gimbal_y_input = state.z

func _process(_delta: float):
	"""Čita roll input iz InputMap."""
	roll_input = 0.0
	if Input.is_action_pressed("roll_right"):
		roll_input += 1.0
	if Input.is_action_pressed("roll_left"):
		roll_input -= 1.0

# UPRAVLJANJE ULAZIMA

func set_control_input(p_throttle: float, p_gimbal_x: float, p_gimbal_y: float, p_roll: float = 0.0):
	"""postavlja upravljačke ulaze i ograničava ih u dozvoljene raspone."""
	throttle_input = clamp(p_throttle, 0.0, 1.0)
	gimbal_x_input = clamp(p_gimbal_x, -1.0, 1.0)
	gimbal_y_input = clamp(p_gimbal_y, -1.0, 1.0)
	roll_input = clamp(p_roll, -1.0, 1.0)

func get_control_input() -> Vector3:
	"""vraća (u_T, u_x, u_y) kao vektor. Roll se dohvaća posebno."""
	return Vector3(throttle_input, gimbal_x_input, gimbal_y_input)

func get_roll_input() -> float:
	"""Vraća roll input [-1, 1]."""
	return roll_input

func get_roll_angular_velocity() -> float:
	"""Vraća željenu kutnu brzinu rolla u rad/s."""
	if game_profile:
		return roll_input * game_profile.roll_speed
	return roll_input * 2.0  # default 2 rad/s

func reset_inputs():
	"""resetira sve ulaze na nulu."""
	throttle_input = 0.0
	gimbal_x_input = 0.0
	gimbal_y_input = 0.0
	roll_input = 0.0

# DEBUG

func get_input_info() -> String:
	var gimbal_magnitude = sqrt(gimbal_x_input * gimbal_x_input + gimbal_y_input * gimbal_y_input)
	var gimbal_angle = atan2(gimbal_y_input, gimbal_x_input)
	
	var throttle_str = "%.3f" % throttle_input
	var gimbal_x_str = "%.3f" % gimbal_x_input
	var gimbal_y_str = "%.3f" % gimbal_y_input
	var gimbal_mag_str = "%.3f" % gimbal_magnitude
	var gimbal_az_str = "%.2f" % rad_to_deg(gimbal_angle)
	var roll_str = "%.3f" % roll_input
	var roll_vel_str = "%.2f" % get_roll_angular_velocity()
	
	var info = """
Upravljački ulazi:
===================================
Throttle (u_T):          %s [0, 1]
Gimbal X (u_x):          %s [-1, 1]
Gimbal Y (u_y):          %s [-1, 1]
Gimbal magnitude:        %s
Gimbal azimut:           %s deg
Roll input:              %s [-1, 1]
Roll velocity:           %s rad/s
===================================
""" % [throttle_str, gimbal_x_str, gimbal_y_str, gimbal_mag_str, gimbal_az_str, roll_str, roll_vel_str]
	
	return info

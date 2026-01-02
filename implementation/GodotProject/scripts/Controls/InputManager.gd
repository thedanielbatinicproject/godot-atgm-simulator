extends Node
class_name InputManager

# SIGNALI
signal input_state_changed(state: Vector3)
signal controls_enabled(enabled: bool)
signal gimbal_changed(gimbal: Vector2)
signal throttle_changed(throttle: float)

# CHILD REFERENCES
var stick_controller: StickController
var throttle_controller: ThrottleController

# KONFIGURACIJA
@export var config: ControlConfig
@export var debug_mode: bool = false

# STATE
var current_input: Vector3 = Vector3.ZERO
var controls_active: bool = true

func _ready():
	# Pronađi ili kreiraj child kontrolere
	_setup_controllers()
	
	# Poveži signale
	_connect_signals()
	
	if debug_mode:
		print("[InputManager] Initialized")

func _setup_controllers():
	# Pronađi StickController
	stick_controller = _find_child_of_type("StickController") as StickController
	if not stick_controller:
		push_warning("[InputManager] StickController not found as child!")
	
	# Pronađi ThrottleController
	throttle_controller = _find_child_of_type("ThrottleController") as ThrottleController
	if not throttle_controller:
		push_warning("[InputManager] ThrottleController not found as child!")
	
	# Primijeni config ako postoji
	if config:
		if stick_controller:
			stick_controller.set_config(config)
		if throttle_controller:
			throttle_controller.set_config(config)

func _find_child_of_type(type_name: String) -> Node:
	# Traži rekurzivno kroz sve child nodove
	return _find_node_recursive(self, type_name)

func _find_node_recursive(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.get_class() == type_name or (child.get_script() and child.get_script().get_global_name() == type_name):
			return child
		var found = _find_node_recursive(child, type_name)
		if found:
			return found
	return null

func _connect_signals():
	if stick_controller:
		stick_controller.gimbal_changed.connect(_on_gimbal_changed)
	
	if throttle_controller:
		throttle_controller.throttle_changed.connect(_on_throttle_changed)

func _on_gimbal_changed(gimbal: Vector2):
	current_input.y = gimbal.x  # u_x
	current_input.z = gimbal.y  # u_y
	
	gimbal_changed.emit(gimbal)
	input_state_changed.emit(current_input)
	
	if debug_mode:
		print("[InputManager] Gimbal: u_x=%.3f, u_y=%.3f" % [gimbal.x, gimbal.y])

func _on_throttle_changed(throttle: float):
	current_input.x = throttle  # u_T
	
	throttle_changed.emit(throttle)
	input_state_changed.emit(current_input)
	
	if debug_mode:
		print("[InputManager] Throttle: u_T=%.3f" % throttle)

# ============ PUBLIC API ============

func get_control_input() -> Vector3:
	"""Vrati trenutni input kao Vector3(u_T, u_x, u_y)."""
	return current_input

func get_throttle() -> float:
	"""Vrati samo throttle vrijednost."""
	return current_input.x

func get_gimbal() -> Vector2:
	"""Vrati samo gimbal kao Vector2(u_x, u_y)."""
	return Vector2(current_input.y, current_input.z)

# CONTROL MANAGEMENT

func enable_controls() -> void:
	"""Omogući sve kontrole."""
	controls_active = true
	
	if stick_controller:
		stick_controller.enable()
	if throttle_controller:
		throttle_controller.enable()
	
	controls_enabled.emit(true)
	
	if debug_mode:
		print("[InputManager] Controls ENABLED")

func disable_controls() -> void:
	"""Onemogući sve kontrole."""
	controls_active = false
	
	if stick_controller:
		stick_controller.disable()
	if throttle_controller:
		throttle_controller.disable()
	
	controls_enabled.emit(false)
	
	if debug_mode:
		print("[InputManager] Controls DISABLED")

func set_controls_enabled(enabled: bool) -> void:
	if enabled:
		enable_controls()
	else:
		disable_controls()

func are_controls_enabled() -> bool:
	return controls_active

func reset_controls() -> void:
	"""Reset sve kontrole na default vrijednosti."""
	if stick_controller:
		stick_controller.reset_input()
	if throttle_controller:
		throttle_controller.reset_input()
	
	current_input = Vector3.ZERO
	input_state_changed.emit(current_input)
	
	if debug_mode:
		print("[InputManager] Controls RESET")

# GRANULARNA KONTROLA

func enable_gimbal(enabled: bool) -> void:
	"""Omogući/onemogući samo gimbal."""
	if stick_controller:
		stick_controller.set_enabled(enabled)
	
	if debug_mode:
		print("[InputManager] Gimbal: %s" % ("ENABLED" if enabled else "DISABLED"))

func enable_throttle(enabled: bool) -> void:
	"""Omogući/onemogući samo throttle."""
	if throttle_controller:
		throttle_controller.set_enabled(enabled)
	
	if debug_mode:
		print("[InputManager] Throttle: %s" % ("ENABLED" if enabled else "DISABLED"))

# CONFIGURATION

func set_config(new_config: ControlConfig) -> void:
	"""Dinamički promijeni konfiguraciju za sve kontrolere."""
	config = new_config
	
	if stick_controller:
		stick_controller.set_config(config)
	if throttle_controller:
		throttle_controller.set_config(config)
	
	if debug_mode:
		print("[InputManager] Config updated")

func get_config() -> ControlConfig:
	return config

# DEBUG

func get_debug_string() -> String:
	return "Input: u_T=%.3f, u_x=%.3f, u_y=%.3f | Active: %s" % [
		current_input.x, current_input.y, current_input.z,
		"YES" if controls_active else "NO"
	]

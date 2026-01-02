extends Node
class_name ThrottleController

# SIGNALI
signal throttle_changed(throttle: float)

# KONFIGURACIJA
@export var config: ControlConfig

# STATE
var throttle: float = 0.0
var enabled: bool = true

func _ready():
	_apply_config()
	set_process(true)

func _apply_config():
	if not config:
		config = ControlConfig.new()
	throttle = config.throttle_default

func _process(delta):
	if not enabled:
		return
	
	var prev_throttle = throttle
	
	# TIPKOVNICA - W/S
	if config.enable_keyboard_input:
		if Input.is_action_pressed("throttle_increase"):
			throttle = minf(throttle + config.throttle_increment_per_second * delta, config.throttle_max)
		
		if Input.is_action_pressed("throttle_decrease"):
			throttle = maxf(throttle - config.throttle_increment_per_second * delta, config.throttle_min)
	
	# GAMEPAD - RT/LT triggers (analogne)
	if config.enable_gamepad_input:
		var rt = Input.get_action_strength("throttle_increase")
		var lt = Input.get_action_strength("throttle_decrease")
		
		# Ako je trigger pritisnut
		if rt > config.deadzone_joystick or lt > config.deadzone_joystick:
			var delta_throttle = (rt - lt) * config.throttle_increment_per_second * delta
			throttle = clampf(throttle + delta_throttle, config.throttle_min, config.throttle_max)
	
	# Emit ako se promijenilo
	if abs(throttle - prev_throttle) > 0.001:
		throttle_changed.emit(throttle)

# PUBLIC API

func get_throttle() -> float:
	return throttle

func get_input_vector() -> Vector3:
	"""Kompatibilnost sa BaseInputController."""
	return Vector3(throttle, 0.0, 0.0)

func set_throttle(value: float) -> void:
	throttle = clampf(value, config.throttle_min, config.throttle_max)
	throttle_changed.emit(throttle)

func reset_input() -> void:
	"""Reset throttle na default."""
	throttle = config.throttle_default
	throttle_changed.emit(throttle)

func enable() -> void:
	enabled = true

func disable() -> void:
	enabled = false

func set_enabled(value: bool) -> void:
	if value:
		enable()
	else:
		disable()

func is_enabled() -> bool:
	return enabled

func set_config(new_config: ControlConfig) -> void:
	config = new_config
	_apply_config()

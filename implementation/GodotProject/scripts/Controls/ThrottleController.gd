extends Node
class_name ThrottleController

# SIGNALI
signal throttle_changed(throttle: float)

# KONFIGURACIJA
@export var config: ControlConfig

# STATE

var throttle: float = 0.0
var enabled: bool = true
# Cooldown timer za joystick throttle
var _joystick_throttle_cooldown: float = 0.0
# Praćenje prethodnog stanja joystick throttle
var _prev_joystick_throttle_active: bool = false

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
	
	# JOYSTICK THROTTLE ima prioritet nad tipkovnicom, s cooldownom
	var joystick_value = 0.0
	var joystick_throttle_now = false
	if config.enable_gamepad_input:
		joystick_value = Input.get_action_strength("joystick_throttle")
		if abs(joystick_value) > config.throttle_joystick_deadzone:
			joystick_throttle_now = true
			throttle = clampf(joystick_value, config.throttle_min, config.throttle_max)
			_joystick_throttle_cooldown = config.throttle_joystick_cooldown_time

	# Odbroji cooldown
	if _joystick_throttle_cooldown > 0.0:
		_joystick_throttle_cooldown -= delta
		if _joystick_throttle_cooldown < 0.0:
			_joystick_throttle_cooldown = 0.0

	var joystick_throttle_active = _joystick_throttle_cooldown > 0.0

	# Ako joystick nije aktivan, koristi tipkovnicu
	if not joystick_throttle_active and config.enable_keyboard_input:
		if Input.is_action_pressed("throttle_increase"):
			throttle = minf(throttle + config.throttle_increment_per_second * delta, config.throttle_max)
		if Input.is_action_pressed("throttle_decrease"):
			throttle = maxf(throttle - config.throttle_increment_per_second * delta, config.throttle_min)

	# Resetiraj throttle na 0 samo na prijelazu s aktivnog joysticka na neaktivni
	if _prev_joystick_throttle_active and not joystick_throttle_active:
		throttle = 0.0
	_prev_joystick_throttle_active = joystick_throttle_active
	
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

extends Resource
class_name ControlConfig

# STICK CONTROLLER
@export_group("Stick Controller")
@export var stick_radius: float = 150.0
@export var cursor_radius: float = 10.0
@export var center_dot_radius: float = 3.0

# ANIMACIJA POVRATKA
@export_group("Return Animation")
@export var return_animation_duration: float = 0.3
@export_enum("LINEAR", "SINE", "QUINT", "QUART", "QUAD", "EXPO", "ELASTIC", "CUBIC", "CIRC", "BOUNCE", "BACK", "SPRING") var return_animation_trans: int = Tween.TRANS_CUBIC
@export_enum("IN", "OUT", "IN_OUT", "OUT_IN") var return_animation_ease: int = Tween.EASE_OUT

# THROTTLE
@export_group("Throttle")
@export var throttle_increment_per_second: float = 1.0
@export var throttle_default: float = 0.0
@export var throttle_min: float = 0.0
@export var throttle_max: float = 1.0
# Deadzone za joystick throttle (RT/LT)
@export var throttle_joystick_deadzone: float = 0.08
# Cooldown vrijeme (sekunde) nakon zadnjeg joystick throttle unosa
@export var throttle_joystick_cooldown_time: float = 0.25

# DEADZONES
@export_group("Deadzones")
@export var deadzone_joystick: float = 0.1
@export var deadzone_mouse: float = 5.0

# INPUT TOGGLES
@export_group("Input Sources")
@export var enable_mouse_input: bool = true
@export var enable_keyboard_input: bool = true
@export var enable_gamepad_input: bool = true

# VIZUALNI STIL
@export_group("Visual Style")
@export var background_color: Color = Color(0.5, 0.5, 0.5, 0.3)
@export var cursor_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var center_dot_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var border_width: float = 2.0

func _init():
	resource_local_to_scene = true

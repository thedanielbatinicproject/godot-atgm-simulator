extends Node
class_name Guidance

# UPRAVLJAČKI ULAZI
var throttle_input: float = 0.0
var gimbal_x_input: float = 0.0
var gimbal_y_input: float = 0.0

# INICIJALIZACIJA

func _init():
	reset_inputs()

# UPRAVLJANJE ULAZIMA

func set_control_input(p_throttle: float, p_gimbal_x: float, p_gimbal_y: float):
	"""postavlja upravljačke ulaze i ograničava ih u dozvoljene raspone."""
	throttle_input = clamp(p_throttle, 0.0, 1.0)
	gimbal_x_input = clamp(p_gimbal_x, -1.0, 1.0)
	gimbal_y_input = clamp(p_gimbal_y, -1.0, 1.0)

func get_control_input() -> Vector3:
	"""vraća (u_T, u_x, u_y) kao vektor."""
	return Vector3(throttle_input, gimbal_x_input, gimbal_y_input)

func reset_inputs():
	"""resetira sve ulaze na nulu."""
	throttle_input = 0.0
	gimbal_x_input = 0.0
	gimbal_y_input = 0.0

# DEBUG

func get_input_info() -> String:
	var gimbal_magnitude = sqrt(gimbal_x_input * gimbal_x_input + gimbal_y_input * gimbal_y_input)
	var gimbal_angle = atan2(gimbal_y_input, gimbal_x_input)
	
	var info = """
Upravljački ulazi:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Throttle (u_T):          %.3f [0, 1]
Gimbal X (u_x):          %.3f [-1, 1]
Gimbal Y (u_y):          %.3f [-1, 1]
Gimbal magnitude:        %.3f
Gimbal azimut:           %.2f °
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
""" % [throttle_input, gimbal_x_input, gimbal_y_input, gimbal_magnitude, rad_to_deg(gimbal_angle)]
	
	return info

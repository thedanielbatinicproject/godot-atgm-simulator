extends Node
class_name StateVariables

var rocket_data: Resource

# VARIJABLE STANJA - TRANSLACIJA
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO

# VARIJABLE STANJA - ROTACIJA
var angular_velocity: Vector3 = Vector3.ZERO

# Eulerovi kutovi (ZYX konvencija)
var alpha: float = 0.0
var beta: float = 0.0
var gamma: float = 0.0

# POMOĆNE VARIJABLE - ULAZI SA VREMENSKIM KAŠNJENJEM
var last_thrust_input: float = 0.0
var last_thrust_time: float = 0.0

var last_gimbal_input: Vector2 = Vector2.ZERO
var last_gimbal_time: float = 0.0

# INICIJALIZACIJA

func _init(p_rocket_data: Resource = null):
	rocket_data = p_rocket_data

# RESET

func reset():
	"""resetira sve varijable na početne vrijednosti."""
	position = Vector3.ZERO
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	alpha = 0.0
	beta = 0.0
	gamma = 0.0
	last_thrust_input = 0.0
	last_thrust_time = 0.0
	last_gimbal_input = Vector2.ZERO
	last_gimbal_time = 0.0

# DEBUG

func get_state_info() -> String:
	"""vraća formatiran string s trenutnim stanjem."""
	var info = """
Stanje projektila:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pozicija:                (%.3f, %.3f, %.3f) m
Brzina:                  (%.3f, %.3f, %.3f) m/s
Brzina (magnitude):      %.3f m/s

Kutna brzina:            (%.4f, %.4f, %.4f) rad/s
Eulerovi kutovi:
  α (roll):              %.2f ° (%.4f rad)
  β (pitch):             %.2f ° (%.4f rad)
  γ (yaw):               %.2f ° (%.4f rad)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
""" % [
		position.x, position.y, position.z,
		velocity.x, velocity.y, velocity.z,
		velocity.length(),
		angular_velocity.x, angular_velocity.y, angular_velocity.z,
		rad_to_deg(alpha), alpha,
		rad_to_deg(beta), beta,
		rad_to_deg(gamma), gamma
	]
	return info


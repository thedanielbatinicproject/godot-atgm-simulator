extends Node
class_name StateVariables

var rocket_data: RocketData

# VARIJABLE STANJA - TRANSLACIJA
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO

# VARIJABLE STANJA - ROTACIJA
var angular_velocity: Vector3 = Vector3.ZERO  # Kutna brzina u lokalnom sustavu projekitila

# Rotacijska matrica (lokalno -> globalno)
var rotation_basis: Basis = Basis.IDENTITY

# Eulerovi kutovi (α=roll, β=pitch, γ=yaw) - izvedeni iz rotation_basis
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
	rotation_basis = Basis.IDENTITY
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
	var roll_deg = "%.2f" % rad_to_deg(alpha)
	var pitch_deg = "%.2f" % rad_to_deg(beta)
	var yaw_deg = "%.2f" % rad_to_deg(gamma)
	var pos_x = "%.3f" % position.x
	var pos_y = "%.3f" % position.y
	var pos_z = "%.3f" % position.z
	var vel_x = "%.3f" % velocity.x
	var vel_y = "%.3f" % velocity.y
	var vel_z = "%.3f" % velocity.z
	var vel_mag = "%.3f" % velocity.length()
	var omega_x = "%.4f" % angular_velocity.x
	var omega_y = "%.4f" % angular_velocity.y
	var omega_z = "%.4f" % angular_velocity.z
	var alpha_rad = "%.4f" % alpha
	var beta_rad = "%.4f" % beta
	var gamma_rad = "%.4f" % gamma
	
	var info = """
Stanje projektila:
===================================
Pozicija:                (%s, %s, %s) m
Brzina:                  (%s, %s, %s) m/s
Brzina (magnitude):      %s m/s

Kutna brzina:            (%s, %s, %s) rad/s
Eulerovi kutovi:
  roll:                  %s deg (%s rad)
  pitch:                 %s deg (%s rad)
  yaw:                   %s deg (%s rad)
===================================
""" % [
		pos_x, pos_y, pos_z,
		vel_x, vel_y, vel_z,
		vel_mag,
		omega_x, omega_y, omega_z,
		roll_deg, alpha_rad,
		pitch_deg, beta_rad,
		yaw_deg, gamma_rad
	]
	return info


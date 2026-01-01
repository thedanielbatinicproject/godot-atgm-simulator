extends Node
class_name Forces

# KONFIGURACIJA
var rocket_data: Resource
var environment: ModelEnvironment
var utils: Utils

# INICIJALIZACIJA

func _init(p_rocket_data: Resource = null, p_environment: ModelEnvironment = null, p_utils: Utils = null):
	rocket_data = p_rocket_data
	environment = p_environment
	utils = p_utils

# SILE

func calculate_gravity(_state: StateVariables) -> Vector3:
	"""gravitacijska sila (globalni sustav)."""
	if not rocket_data or not environment:
		return Vector3.ZERO
	return Vector3(0, 0, -rocket_data.mass * environment.gravity)

func calculate_buoyancy(_state: StateVariables) -> Vector3:
	"""uzgonska sila (globalni sustav)."""
	if not rocket_data or not environment:
		return Vector3.ZERO
	return Vector3(0, 0, environment.air_density * environment.gravity * rocket_data.volume)

func calculate_thrust(_state: StateVariables, _guidance_input: Vector3) -> Vector3:
	"""potisna sila - implementacija u fazi 2."""
	return Vector3.ZERO

func calculate_drag(_state: StateVariables, _wind_velocity: Vector3) -> Vector3:
	"""otpor zraka - implementacija u fazi 2."""
	return Vector3.ZERO

# UKUPNA SILA

func calculate_total(state: StateVariables, guidance_input: Vector3, wind_velocity: Vector3 = Vector3.ZERO) -> Vector3:
	"""kombinira sve vanjske sile."""
	var f_gravity = calculate_gravity(state)
	var f_buoyancy = calculate_buoyancy(state)
	var f_thrust = calculate_thrust(state, guidance_input)
	var f_drag = calculate_drag(state, wind_velocity)
	
	return f_gravity + f_buoyancy + f_thrust + f_drag

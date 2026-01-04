extends Node
class_name Moments

# Godot sustav: X=desno, Y=gore, Z=naprijed (nos)

var rocket_data: RocketData
var environment: ModelEnvironment
var utils: Utils

func _init(p_rocket_data: RocketData = null, p_environment = null, p_utils = null):
	rocket_data = p_rocket_data
	environment = p_environment
	utils = p_utils

func calculate_thrust_moment(_state: StateVariables, thrust_force_local: Vector3) -> Vector3:
	"""Moment od gimbala. M = r × F, gdje r ide OD težišta DO propulzora."""
	if not rocket_data or not utils:
		return Vector3.ZERO
	
	var zcm_local = rocket_data.compute_center_of_mass_local()
	var r_prop = Vector3(0.0, 0.0, -zcm_local)
	return r_prop.cross(thrust_force_local)

func calculate_rotational_damping(state: StateVariables) -> Vector3:
	"""
	Kvadratno rotacijsko prigušenje: M = -c * |ω| * ω
	Realistično modelira aerodinamički otpor rotaciji.
	"""
	if not rocket_data:
		return Vector3.ZERO
	
	var omega = state.angular_velocity
	var omega_mag = omega.length()
	
	if omega_mag < 0.001:
		return Vector3.ZERO
	
	var c = rocket_data.rotational_damping_coefficient
	return -c * omega_mag * omega

func calculate_total(state: StateVariables, thrust_force_local: Vector3, _wind_velocity: Vector3 = Vector3.ZERO) -> Vector3:
	"""Ukupni moment u lokalnom sustavu."""
	var m_thrust = calculate_thrust_moment(state, thrust_force_local)
	var m_damping = calculate_rotational_damping(state)
	
	return m_thrust + m_damping
	

extends Node
class_name Moments

# Godot sustav: X=desno, Y=gore, Z=naprijed (nos)

var rocket_data: RocketData
var environment: ModelEnvironment
var utils: Utils
var game_profile: GameProfileData

func _init(p_rocket_data: RocketData = null, p_environment = null, p_utils = null, p_game_profile: GameProfileData = null):
	rocket_data = p_rocket_data
	environment = p_environment
	utils = p_utils
	game_profile = p_game_profile

func calculate_thrust_moment(_state: StateVariables, thrust_force_local: Vector3) -> Vector3:
	"""Moment od gimbala. M = r × F, gdje r ide OD težišta DO propulzora."""
	if not rocket_data or not utils:
		return Vector3.ZERO
	
	var zcm_local = rocket_data.compute_center_of_mass_local()
	var r_prop = Vector3(0.0, 0.0, -zcm_local)
	return r_prop.cross(thrust_force_local)

func calculate_idle_moment(state: StateVariables) -> Vector3:
	"""
	Moment kada je potisak na 0, ali i dalje želimo minimalnu kontrolu.
	Ovo simulira npr. aerodinamičke kontrolne površine ili RCS.
	Koristi idle_moment_thrust_percentage iz GameProfile.
	"""
	if not rocket_data or not game_profile:
		return Vector3.ZERO
	
	var idle_factor = game_profile.get_idle_thrust_factor()
	if idle_factor <= 0.0:
		return Vector3.ZERO
	
	# Simuliraj potisak kao da je na idle_factor za potrebe momenta
	var idle_thrust_magnitude = rocket_data.max_thrust * idle_factor
	
	# Koristi aktivni gimbal input za izračun smjera
	var input_x = -state.active_gimbal_input.x  # Inverzija za yaw
	var input_y = state.active_gimbal_input.y
	
	var gimbal_magnitude = Vector2(input_x, input_y).length()
	var gimbal_angle = rocket_data.max_thrust_angle * minf(gimbal_magnitude, 1.0)
	var gimbal_azimuth = atan2(input_y, input_x)
	
	var idle_thrust_local = idle_thrust_magnitude * Vector3(
		-sin(gimbal_angle) * cos(gimbal_azimuth),
		-sin(gimbal_angle) * sin(gimbal_azimuth),
		cos(gimbal_angle)
	)
	
	return calculate_thrust_moment(state, idle_thrust_local)

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
	var m_thrust: Vector3
	
	# Ako je potisak praktički 0, koristi idle moment iz GameProfile
	var thrust_mag = thrust_force_local.length()
	if thrust_mag < 0.1:
		m_thrust = calculate_idle_moment(state)
	else:
		m_thrust = calculate_thrust_moment(state, thrust_force_local)
	
	var m_damping = calculate_rotational_damping(state)
	
	return m_thrust + m_damping
	

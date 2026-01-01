extends Node
class_name Moments

# KONFIGURACIJA
var rocket_data: RocketData
var environment: ModelEnvironment
var utils: Utils

# INICIJALIZACIJA

func _init(p_rocket_data: RocketData = null, p_environment = null, p_utils = null):
	rocket_data = p_rocket_data
	environment = p_environment
	utils = p_utils

# MOMENTI

func calculate_thrust_moment(_state: StateVariables, thrust_force_local: Vector3) -> Vector3:
	"""
	moment od asimetrične potisne sile.
	M = r × F gdje je r pomak centra mase od propulzora.
	Sve varijable u lokalnom sustavu.
	"""
	if not rocket_data or not utils:
		return Vector3.ZERO
	
	# pomak centra mase od propulzora (ishodišta) duž lokalne x-osi
	var xcm_local = rocket_data.compute_center_of_mass_local()
	var r_cm = Vector3(xcm_local, 0.0, 0.0)
	
	# moment: M = r × F (vektorski umnožak)
	var moment_local = r_cm.cross(thrust_force_local)
	
	return moment_local

func calculate_stabilization_moment(state: StateVariables, _environment_ref: Resource = null) -> Vector3:
	if not rocket_data or not environment:
		return Vector3.ZERO
	
	var wind_velocity = environment.get_wind_at_position(state.position)
	var v_rel_global = state.velocity - wind_velocity
	var v_rel_mag = v_rel_global.length()
	
	if v_rel_mag < 0.1:
		return Vector3.ZERO
	
	var v_rel_unit = v_rel_global / v_rel_mag
	var x_proj = state.rotation_basis.x
	
	var cos_delta_theta = x_proj.dot(v_rel_unit)
	if cos_delta_theta > 0.9999:
		return Vector3.ZERO
	
	var sin_delta_theta = sqrt(1.0 - cos_delta_theta * cos_delta_theta)
	
	var cross = x_proj.cross(v_rel_unit)
	var cross_mag = cross.length()
	
	if cross_mag < 1e-6:
		return Vector3.ZERO
	
	var n_perp = cross / cross_mag
	
	var R = rocket_data.radius
	var rho = environment.air_density
	var moment_mag = -2.0 * PI * pow(R, 3) * rho * pow(v_rel_mag, 2) * sin_delta_theta
	
	return moment_mag * n_perp

# UKUPAN MOMENT

func calculate_total(state: StateVariables, thrust_force_local: Vector3, _wind_velocity: Vector3 = Vector3.ZERO) -> Vector3:
	var m_thrust = calculate_thrust_moment(state, thrust_force_local)
	var m_stab = calculate_stabilization_moment(state)
	var b_rotational = 0.2
	var m_rotational_drag = -b_rotational * state.angular_velocity
	return m_thrust + m_stab + m_rotational_drag

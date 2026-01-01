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
	if not rocket_data or not environment or not utils:
		return Vector3.ZERO
	
	var wind_velocity = environment.get_wind_at_position(state.position)
	var v_rel_global = state.velocity - wind_velocity
	var v_rel_mag = v_rel_global.length()
	
	if v_rel_mag < 0.1:
		return Vector3.ZERO
	
	var rotation_matrix = state.rotation_basis
	var det = rotation_matrix.determinant()
	
	if abs(det - 1.0) > 0.01:
		return Vector3.ZERO
	
	var col0_len = rotation_matrix.x.length()
	var col1_len = rotation_matrix.y.length()
	var col2_len = rotation_matrix.z.length()
	
	if abs(col0_len - 1.0) > 0.01 or abs(col1_len - 1.0) > 0.01 or abs(col2_len - 1.0) > 0.01:
		return Vector3.ZERO
	
	var v_rel_local = rotation_matrix.transposed() * v_rel_global
	var v_rel_unit_local = v_rel_local / v_rel_mag
	var x_proj_local = Vector3(1.0, 0.0, 0.0)
	var cos_delta_theta = x_proj_local.dot(v_rel_unit_local)
	
	var sin_delta_theta_sq = 1.0 - cos_delta_theta * cos_delta_theta
	if sin_delta_theta_sq < 0.0:
		sin_delta_theta_sq = 0.0
	var sin_delta_theta = sqrt(sin_delta_theta_sq)
	
	if sin_delta_theta < 0.0349:
		return Vector3.ZERO
	
	var cross_prod = x_proj_local.cross(v_rel_unit_local)
	var cross_mag = cross_prod.length()
	
	if cross_mag < 1e-6:
		return Vector3.ZERO
	
	var n_perp_local = cross_prod / cross_mag
	var R = rocket_data.radius
	var rho = environment.air_density
	var moment_mag = -2.0 * PI * R * R * R * rho * v_rel_mag * v_rel_mag * sin_delta_theta
	
	if not is_finite(moment_mag) or abs(moment_mag) > 1000.0:
		if moment_mag > 0:
			moment_mag = minf(abs(moment_mag), 100.0)
		else:
			moment_mag = -minf(abs(moment_mag), 100.0)
	
	var moment_local = moment_mag * n_perp_local
	return moment_local

# UKUPAN MOMENT

func calculate_total(state: StateVariables, thrust_force_local: Vector3, _wind_velocity: Vector3 = Vector3.ZERO) -> Vector3:
	var m_thrust = calculate_thrust_moment(state, thrust_force_local)
	var m_stab = calculate_stabilization_moment(state)
	var b_rotational = 0.2
	var m_rotational_drag = -b_rotational * state.angular_velocity
	return m_thrust + m_stab + m_rotational_drag

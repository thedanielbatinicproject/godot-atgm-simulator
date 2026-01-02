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
	#print("DEBUG thrust_moment: r_cm=(%.3f, %.3f, %.3f), F=(%.3f, %.3f, %.3f), M=(%.3f, %.3f, %.3f)" % [r_cm.x, r_cm.y, r_cm.z, thrust_force_local.x, thrust_force_local.y, thrust_force_local.z, moment_local.x, moment_local.y, moment_local.z])
	
	return moment_local

func calculate_stabilization_moment(state: StateVariables, _environment_ref: Resource = null) -> Vector3:
	"""Aerodinamički stabilizacijski moment u Model koordinatama."""
	if not rocket_data or not environment:
		return Vector3.ZERO
	
	# Konvertira poziciju u Godot za wind lookup
	var position_godot = Utils.model_to_godot(state.position)
	var wind_velocity_godot = environment.get_wind_at_position(position_godot)
	# Konvertira wind u Model koordinate
	var wind_velocity = Utils.godot_to_model(wind_velocity_godot)
	
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
	
	# Rotacijski otpor (aerodinamički) - proporcionalan kutnoj brzini
	# b treba biti dovoljno velik da priguši giroskopske efekte
	# Za malu raketu sa I ~ 0.002, b ~ 0.01-0.1 je razumno
	var b_rotational = 0.05  # N·m·s/rad
	var m_rotational_drag = -b_rotational * state.angular_velocity
	
	return m_thrust + m_rotational_drag  + m_stab# kad bude stabilan

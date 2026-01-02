extends Node
class_name Moments

# ============================================================================
# GODOT KOORDINATNI SUSTAV
# ============================================================================
# X = desno, Y = gore, Z = naprijed (nos projektila)
# Lokalni sustav projektila: Z = os nosa, X = desno, Y = gore
# Momenti: M oko X = pitch, M oko Y = yaw, M oko Z = roll
# ============================================================================

# KONFIGURACIJA
var rocket_data: RocketData
var environment: ModelEnvironment
var utils: Utils

# INICIJALIZACIJA

func _init(p_rocket_data: RocketData = null, p_environment = null, p_utils = null):
	rocket_data = p_rocket_data
	environment = p_environment
	utils = p_utils

# ============================================================================
# MOMENTI
# ============================================================================

func calculate_thrust_moment(_state: StateVariables, thrust_force_local: Vector3) -> Vector3:
	"""
	Moment od asimetrične potisne sile.
	M = r × F gdje je r pomak centra mase od propulzora.
	
	U Godot sustavu:
	  - Propulzor je na Z=0 (baza)
	  - Težište je na Z=z_cm (prema nosu)
	  - r_cm = (0, 0, z_cm)
	"""
	if not rocket_data or not utils:
		return Vector3.ZERO
	
	# Pomak centra mase od propulzora duž lokalne Z osi (osi nosa)
	var zcm_local = rocket_data.compute_center_of_mass_local()
	var r_cm = Vector3(0.0, 0.0, zcm_local)
	
	# Moment: M = r × F (vektorski umnožak)
	var moment_local = r_cm.cross(thrust_force_local)
	
	return moment_local

func calculate_stabilization_moment(state: StateVariables, _environment_ref: Resource = null) -> Vector3:
	"""
	Aerodinamički stabilizacijski moment.
	
	Moment želi poravnati projektil sa smjerom leta.
	M_stab = -C * ρ * R³ * |v|² * sin(Δθ) * n̂
	
	gdje je:
	  - Δθ = kut između smjera projektila i smjera leta
	  - n̂ = os oko koje treba rotirati da se poravnaju
	"""
	if not rocket_data or not environment:
		return Vector3.ZERO
	
	# Relativna brzina (sve u Godot koordinatama)
	var wind_velocity = environment.get_wind_at_position(state.position)
	var v_rel = state.velocity - wind_velocity
	var v_rel_mag = v_rel.length()
	
	if v_rel_mag < 0.1:
		return Vector3.ZERO
	
	var v_rel_unit = v_rel / v_rel_mag
	
	# Smjer projektila (lokalna Z os = nos)
	var z_proj = state.rotation_basis.z
	
	# Kut između smjera projektila i smjera leta
	var cos_delta_theta = z_proj.dot(v_rel_unit)
	if cos_delta_theta > 0.9999:
		return Vector3.ZERO  # Već poravnato
	
	var sin_delta_theta = sqrt(1.0 - cos_delta_theta * cos_delta_theta)
	
	# Os rotacije (okomita na obje)
	var cross = z_proj.cross(v_rel_unit)
	var cross_mag = cross.length()
	
	if cross_mag < 1e-6:
		return Vector3.ZERO
	
	var n_perp = cross / cross_mag
	
	# Stabilizacijski moment
	var R = rocket_data.radius
	var rho = environment.air_density
	var C_M = rocket_data.stabilization_moment_coefficient  # C_M,α = 2.0
	var moment_mag = -C_M * PI * pow(R, 3) * rho * pow(v_rel_mag, 2) * sin_delta_theta
	
	return moment_mag * n_perp

# ============================================================================
# UKUPAN MOMENT
# ============================================================================

func calculate_total(state: StateVariables, thrust_force_local: Vector3, _wind_velocity: Vector3 = Vector3.ZERO) -> Vector3:
	"""Kombinira sve momente."""
	var m_thrust = calculate_thrust_moment(state, thrust_force_local)
	var m_stab = calculate_stabilization_moment(state)
	
	# Rotacijsko prigušenje (aerodinamičko) - proporcionalno kutnoj brzini
	# Ovo stabilizira simulaciju i sprečava divergenciju
	var b_rotational = 0.05  # N·m·s/rad
	var m_rotational_drag = -b_rotational * state.angular_velocity
	
	return m_thrust #+ m_rotational_drag + m_stab

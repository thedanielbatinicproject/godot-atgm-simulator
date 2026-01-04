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
	Moment od asimetrične potisne sile OKO TEŽIŠTA.
	M = r × F gdje je r vektor OD TEŽIŠTA DO HVATIŠTA SILE (propulzora).
	
	U Godot sustavu:
	  - Propulzor je na Z=0 (baza) - HVATIŠTE SILE
	  - Težište je na Z=z_cm (prema nosu)
	  - r_prop = (0, 0, -z_cm) - vektor OD težišta DO propulzora
	
	Fizika:
	  - Ako je gimbal udesno, reakcijska sila ima komponentu ulijevo (-X)
	  - r_prop × F_lijevo = moment koji okreće nos UDESNO (pozitivan yaw)
	"""
	if not rocket_data or not utils:
		return Vector3.ZERO
	
	# Vektor OD TEŽIŠTA DO PROPULZORA (hvatišta sile)
	# Težište je na +Z, propulzor na Z=0, dakle r_prop ide u -Z smjeru
	var zcm_local = rocket_data.compute_center_of_mass_local()
	var r_prop = Vector3(0.0, 0.0, -zcm_local)  # OD težišta DO propulzora
	
	# Moment: M = r × F (vektorski umnožak)
	var moment_local = r_prop.cross(thrust_force_local)
	
	return moment_local

func calculate_stabilization_moment(state: StateVariables, _environment_ref: Resource = null) -> Vector3:
	"""
	Aerodinamički stabilizacijski moment.
	
	Moment želi poravnati projektil sa smjerom leta (weathercock stability).
	Formula: M_stab = C * ρ * R³ * |v|² * sin(Δθ) * n̂
	
	gdje je:
	  - Δθ = kut između smjera projektila i smjera leta
	  - n̂ = os rotacije koja PORAVNAVA projektil s brzinom
	  - n̂ = v_rel × z_proj (normalizirano) - smjer koji vraća nos prema brzini
	
	FIZIKA:
	  Ako projektil "klizi" (nos nije u smjeru leta), aerodinamičke sile
	  stvaraju moment koji ga vraća. Ovo je kao strelica koja se stabilizira.
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
	
	# Os rotacije koja VRAĆA nos prema brzini
	# v_rel × z_proj daje os oko koje rotacija PORAVNAVA projektil s brzinom
	var cross = v_rel_unit.cross(z_proj)
	var cross_mag = cross.length()
	
	if cross_mag < 1e-6:
		return Vector3.ZERO
	
	var n_perp = cross / cross_mag
	
	# Stabilizacijski moment (POZITIVAN - vraća projektil)
	var R = rocket_data.radius
	var rho = environment.air_density
	var C_M = rocket_data.stabilization_moment_coefficient  # C_M,α = 2.0
	var moment_mag = C_M * PI * pow(R, 3) * rho * pow(v_rel_mag, 2) * sin_delta_theta
	
	return moment_mag * n_perp


func calculate_total(state: StateVariables, thrust_force_local: Vector3, _wind_velocity: Vector3 = Vector3.ZERO) -> Vector3:
	"""Kombinira sve momente u LOKALNOM sustavu projektila."""
	var m_thrust = calculate_thrust_moment(state, thrust_force_local)  # LOCAL
	var m_stab_global = calculate_stabilization_moment(state)  # GLOBAL

	var m_stab_local = state.rotation_basis.transposed() * m_stab_global
	
	# Rotacijsko prigušenje (aerodinamičko) - proporcionalno kutnoj brzini
	var m_rotational_drag = -rocket_data.rotational_damping_coefficient * state.angular_velocity
	
	var m_total = m_thrust + m_rotational_drag + m_stab_local
	return m_total
	

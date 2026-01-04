extends Node
class_name Forces

# ============================================================================
# GODOT KOORDINATNI SUSTAV
# ============================================================================
# X = desno, Y = gore, Z = naprijed (nos projektila)
# Gravitacija: -Y smjer
# Uzgon: +Y smjer
# Potisak: +Z smjer (lokalno) = naprijed
# ============================================================================

# KONFIGURACIJA
var rocket_data: RocketData
var environment: ModelEnvironment
var utils: Utils

# INICIJALIZACIJA

func _init(p_rocket_data: RocketData = null, p_environment: ModelEnvironment = null, p_utils: Utils = null):
	rocket_data = p_rocket_data
	environment = p_environment
	utils = p_utils

# ============================================================================
# SILE
# ============================================================================

func calculate_gravity(_state: StateVariables) -> Vector3:
	"""Gravitacijska sila. Djeluje prema dolje (-Y)."""
	if not rocket_data or not environment:
		return Vector3.ZERO
	# Godot sustav: Y = gore, gravitacija djeluje prema dolje
	return Vector3(0, -rocket_data.mass * environment.gravity, 0)

func calculate_buoyancy(_state: StateVariables) -> Vector3:
	"""Sila uzgona. Djeluje prema gore (+Y)."""
	if not rocket_data or not environment:
		return Vector3.ZERO
	# Godot sustav: Y = gore, uzgon djeluje prema gore
	return Vector3(0, environment.air_density * environment.gravity * rocket_data.volume, 0)

func calculate_thrust(state: StateVariables, guidance_input: Vector3, current_time: float) -> Vector3:
	"""
	Potisna sila sa defleksijom u GLOBALNOM sustavu.
	guidance_input = (u_T, u_x, u_y)
	"""
	if not rocket_data or not utils:
		return Vector3.ZERO
	
	# Izračunaj lokalnu silu (reakcijska sila potiska - gura projektil naprijed u +Z)
	var thrust_local = calculate_thrust_local(state, guidance_input, current_time)
	
	# Transformacija u globalni sustav
	var rotation_matrix = utils.euler_to_rotation_matrix(state.alpha, state.beta, state.gamma)
	var thrust_global = rotation_matrix * thrust_local
	
	return thrust_global

func calculate_thrust_local(state: StateVariables, _guidance_input: Vector3, _current_time: float) -> Vector3:
	"""
	Potisna sila (REAKCIJSKA) u LOKALNOM sustavu projektila.
	
	Lokalni sustav: Z = naprijed (nos), X = desno, Y = gore
	Propulzor je na bazi (Z=0) i gura projektil NAPRIJED (+Z).
	
	FIZIKA GIMBALA:
	  1. Korisnik daje input (u_x, u_y)
	  2. Mlaznica se otklanja u smjeru inputa
	  3. Mlaz izlazi u tom smjeru
	  4. REAKCIJSKA sila je SUPROTNA smjeru mlaza
	
	Primjer za u_x > 0 (joystick desno):
	  - Mlaznica se otklanja DESNO (+X)
	  - Mlaz izlazi s komponentom u +X smjeru
	  - Reakcijska sila ima komponentu u -X smjeru
	  - Ova sila stvara moment koji okreće nos DESNO
	"""
	if not rocket_data:
		return Vector3.ZERO
	
	# Koristi aktivne inpute (već prošli latenciju)
	var thrust_magnitude = rocket_data.max_thrust * minf(state.active_thrust_input, 1.0)
	
	# Gimbal iz aktivnog inputa
	var gimbal_magnitude = state.active_gimbal_input.length()
	var gimbal_angle = rocket_data.max_thrust_angle * minf(gimbal_magnitude, 1.0)
	var gimbal_azimuth = atan2(state.active_gimbal_input.y, state.active_gimbal_input.x)
	
	# Reakcijska sila potiska u lokalnom sustavu
	# Glavna komponenta (+Z) gura naprijed
	# Bočne komponente su SUPROTNE od smjera otklona mlaznice (reakcija!)
	var thrust_local = thrust_magnitude * Vector3(
		-sin(gimbal_angle) * cos(gimbal_azimuth),  # X: MINUS jer je reakcija
		-sin(gimbal_angle) * sin(gimbal_azimuth),  # Y: MINUS jer je reakcija
		cos(gimbal_angle)                           # Z = naprijed (glavna, uvijek +)
	)
	
	return thrust_local

func calculate_drag(state: StateVariables) -> Vector3:
	"""
	Aerodinamička sila otpora.
	v_rel = v_proj - v_wind
	F_drag = -0.5 * ρ * C_D * A * |v_rel| * v_rel
	"""
	if not rocket_data or not environment or not utils:
		return Vector3.ZERO
	
	# Relativna brzina (sve u Godot koordinatama)
	var wind_velocity = environment.get_wind_at_position(state.position)
	var v_rel = state.velocity - wind_velocity
	var v_rel_mag = v_rel.length()
	
	# Ako je brzina vrlo mala, nema draga
	if v_rel_mag < 0.1:
		return Vector3.ZERO
	
	# Smjer projektila (lokalna Z os u globalnom sustavu)
	var direction = utils.get_direction_vector(state.alpha, state.beta, state.gamma)
	
	# Kut između smjera projektila i relativne brzine
	var v_rel_unit = v_rel / v_rel_mag
	var cos_theta = clampf(direction.dot(v_rel_unit), -1.0, 1.0)
	var sin_theta = sqrt(1.0 - cos_theta * cos_theta)
	
	# Projicirana površina
	var R = rocket_data.radius
	var H = rocket_data.cylinder_height
	var h = rocket_data.cone_height
	var A_proj = PI * R * R * abs(cos_theta) + R * (2.0 * H + h) * abs(sin_theta)
	
	# Reynoldsov broj
	var L = 2.0 * R
	var Re = environment.air_density * v_rel_mag * L / environment.air_viscosity
	
	# Koeficijent otpora: C_D = C_D0 + k/Re
	var C_D = rocket_data.drag_coefficient_form
	if Re > 1.0:
		C_D += (rocket_data.drag_coefficient_viscous_factor * environment.air_viscosity) / (environment.air_density * v_rel_mag * L)
	
	# Drag force: F = -0.5 * ρ * C_D * A * |v| * v
	var drag_force = -0.5 * environment.air_density * C_D * A_proj * v_rel_mag * v_rel
	
	# Limiter - drag ne smije preći 50% max potiska
	var drag_mag = drag_force.length()
	var max_drag = rocket_data.max_thrust + rocket_data.mass * environment.gravity
	if drag_mag > max_drag:
		drag_force = drag_force.normalized() * max_drag
	
	return drag_force

# ============================================================================
# UKUPNA SILA
# ============================================================================

func calculate_total(state: StateVariables, guidance_input: Vector3, current_time: float) -> Vector3:
	"""Kombinira sve vanjske sile."""
	var f_gravity = calculate_gravity(state)
	var f_buoyancy = calculate_buoyancy(state)
	var f_thrust = calculate_thrust(state, guidance_input, current_time)
	var f_drag = calculate_drag(state)
	
	return f_gravity + f_buoyancy + f_thrust + f_drag

extends Node
class_name Forces

# Godot sustav: X=desno, Y=gore, Z=naprijed (nos)

var rocket_data: RocketData
var environment: ModelEnvironment
var utils: Utils
var game_profile: GameProfileData

func _init(p_rocket_data: RocketData = null, p_environment: ModelEnvironment = null, p_utils: Utils = null, p_game_profile: GameProfileData = null):
	rocket_data = p_rocket_data
	environment = p_environment
	utils = p_utils
	game_profile = p_game_profile

func calculate_gravity(_state: StateVariables) -> Vector3:
	"""Gravitacija: -Y smjer. Poštuje debug opciju calculate_gravity iz projektila."""
	if not rocket_data or not environment:
		return Vector3.ZERO
	# Provjeri postoji li projektil i opcija calculate_gravity
	if has_node(".."):
		var projectile = get_node("..")
		if projectile.has_variable("calculate_gravity") and not projectile.calculate_gravity:
			return Vector3.ZERO
	return Vector3(0, -rocket_data.mass * environment.gravity, 0)

func calculate_buoyancy(_state: StateVariables) -> Vector3:
	"""Uzgon: +Y smjer."""
	if not rocket_data or not environment:
		return Vector3.ZERO
	return Vector3(0, environment.air_density * environment.gravity * rocket_data.volume, 0)

func calculate_thrust(state: StateVariables, guidance_input: Vector3, current_time: float) -> Vector3:
	"""Potisna sila u globalnom sustavu. Koristi rotation_basis direktno (izbjegava gimbal lock)."""
	if not rocket_data:
		return Vector3.ZERO
	
	var thrust_local = calculate_thrust_local(state, guidance_input, current_time)
	# Koristi rotation_basis umjesto Euler kuteva (gimbal lock problem!)
	return state.rotation_basis * thrust_local

func calculate_thrust_local(state: StateVariables, _guidance_input: Vector3, _current_time: float) -> Vector3:
	"""
	Lokalna potisna sila s gimbalom.
	Reakcijska sila je suprotna smjeru mlaza.
	"""
	if not rocket_data:
		return Vector3.ZERO
	
	var thrust_magnitude = rocket_data.max_thrust * minf(state.active_thrust_input, 1.0)
	
	# Invertiramo X jer Godot pozitivna rotacija oko Y = nos LIJEVO
	# S inverzijom: joystick desno → nos desno
	var input_x = -state.active_gimbal_input.x
	var input_y = state.active_gimbal_input.y
	
	var gimbal_magnitude = Vector2(input_x, input_y).length()
	var gimbal_angle = rocket_data.max_thrust_angle * minf(gimbal_magnitude, 1.0)
	var gimbal_azimuth = atan2(input_y, input_x)
	
	return thrust_magnitude * Vector3(
		-sin(gimbal_angle) * cos(gimbal_azimuth),
		-sin(gimbal_angle) * sin(gimbal_azimuth),
		cos(gimbal_angle)
	)

func calculate_drag(state: StateVariables) -> Vector3:
	"""Aerodinamički otpor: F = -0.5 * ρ * C_D * A * |v| * v"""
	if not rocket_data or not environment:
		return Vector3.ZERO
	
	var wind_velocity = environment.get_wind_at_position(state.position)
	var v_rel = state.velocity - wind_velocity
	var v_rel_mag = v_rel.length()
	
	if v_rel_mag < 0.1:
		return Vector3.ZERO
	
	# Smjer nosa iz rotation_basis (izbjegava gimbal lock)
	var direction = state.rotation_basis.z.normalized()
	var v_rel_unit = v_rel / v_rel_mag
	var cos_theta = clampf(direction.dot(v_rel_unit), -1.0, 1.0)
	var sin_theta = sqrt(1.0 - cos_theta * cos_theta)
	
	var R = rocket_data.radius
	var H = rocket_data.cylinder_height
	var h = rocket_data.cone_height
	var A_proj = PI * R * R * abs(cos_theta) + R * (2.0 * H + h) * abs(sin_theta)
	
	var L = 2.0 * R
	var Re = environment.air_density * v_rel_mag * L / environment.air_viscosity
	
	var C_D = rocket_data.drag_coefficient_form
	if Re > 1.0:
		C_D += (rocket_data.drag_coefficient_viscous_factor * environment.air_viscosity) / (environment.air_density * v_rel_mag * L)
	
	var drag_force = -0.5 * environment.air_density * C_D * A_proj * v_rel_mag * v_rel
	
	var drag_mag = drag_force.length()
	var max_drag = rocket_data.max_thrust + rocket_data.mass * environment.gravity
	if drag_mag > max_drag:
		drag_force = drag_force.normalized() * max_drag
	
	return drag_force

func calculate_velocity_alignment(state: StateVariables) -> Vector3:
	"""
	Usklađivanje brzine s orijentacijom projektila.
	
	Kada projektil leti ukošeno, otpor zraka na bok projektila
	stvara silu koja "rotira" vektor brzine prema smjeru nosa.
	Rezultat: brzina konvergira prema osi projektila.
	"""
	if not rocket_data or not environment:
		return Vector3.ZERO
	
	var wind_velocity = environment.get_wind_at_position(state.position)
	var v_rel = state.velocity - wind_velocity
	var v_rel_mag = v_rel.length()
	
	if v_rel_mag < 0.5:
		return Vector3.ZERO
	
	# Smjer nosa projektila
	var z_proj = state.rotation_basis.z.normalized()
	
	# Komponenta brzine u smjeru nosa
	var v_parallel_mag = v_rel.dot(z_proj)
	var v_parallel = v_parallel_mag * z_proj
	
	# Bočna komponenta brzine
	var v_perp = v_rel - v_parallel
	var v_perp_mag = v_perp.length()
	
	if v_perp_mag < 0.1:
		return Vector3.ZERO
	
	# Sila koja PRENOSI bočnu brzinu u smjer nosa:
	# - Smanjuje v_perp (sila suprotna od v_perp)
	# - Povećava v_parallel (sila u smjeru z_proj)
	# Očuvanje energije: |F_perp| ≈ |F_parallel|
	var k = game_profile.velocity_alignment_coefficient if game_profile else 0.5
	var rho = environment.air_density
	var A_side = rocket_data.radius * (2.0 * rocket_data.cylinder_height + rocket_data.cone_height)
	
	var force_mag = k * rho * A_side * v_perp_mag * v_perp_mag
	
	# Smjer sile: od v_perp prema z_proj (rotira brzinu prema nosu)
	var v_perp_unit = v_perp / v_perp_mag
	
	# Komponenta koja smanjuje bočno klizanje
	var f_reduce_perp = -force_mag * v_perp_unit
	
	# Komponenta koja dodaje brzinu u smjeru nosa (očuvanje količine gibanja)
	# Predznak ovisi o tome leti li projektil naprijed ili natrag
	var sign_parallel = 1.0 if v_parallel_mag >= 0 else -1.0
	var f_add_parallel = force_mag * sign_parallel * z_proj
	
	return f_reduce_perp + f_add_parallel

func calculate_total(state: StateVariables, guidance_input: Vector3, current_time: float) -> Vector3:
	"""Ukupna vanjska sila."""
	var f_gravity = calculate_gravity(state)
	var f_buoyancy = calculate_buoyancy(state)
	var f_thrust = calculate_thrust(state, guidance_input, current_time)
	var f_drag = calculate_drag(state)
	var f_alignment = calculate_velocity_alignment(state)
	
	return f_gravity + f_buoyancy + f_thrust + f_drag + f_alignment

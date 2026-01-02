extends Node
class_name Forces

# KONFIGURACIJA
var rocket_data: RocketData
var environment: ModelEnvironment
var utils: Utils

# INICIJALIZACIJA

func _init(p_rocket_data: RocketData = null, p_environment: ModelEnvironment = null, p_utils: Utils = null):
	rocket_data = p_rocket_data
	environment = p_environment
	utils = p_utils

# SILE

func calculate_gravity(_state: StateVariables) -> Vector3:
	"""gravitacijska sila."""
	if not rocket_data or not environment:
		return Vector3.ZERO
	# Model sustav: X=naprijed, Y=desno, Z=gore
	# Gravitacija djeluje prema dolje, tj. -Z smjer
	return Vector3(0, -rocket_data.mass * environment.gravity, 0)

func calculate_buoyancy(_state: StateVariables) -> Vector3:
	"""sila uzgona"""
	if not rocket_data or not environment:
		return Vector3.ZERO
	# Model sustav: X=naprijed, Y=desno, Z=gore
	# Uzgon djeluje prema gore, tj. +Z smjer
	return Vector3(0, environment.air_density * environment.gravity * rocket_data.volume, 0)

func calculate_thrust(state: StateVariables, guidance_input: Vector3, current_time: float) -> Vector3:
	"""
	potisna sila sa defleksijom i latencijama.
	guidance_input = (u_T, u_x, u_y)
	Vraća globalnu silu.
	"""
	if not rocket_data or not utils:
		return Vector3.ZERO
	
	# izračunaj lokalnu silu (reakcijska sila potiska - gura projektil naprijed)
	var thrust_local = calculate_thrust_local(state, guidance_input, current_time)
	
	# transformacija u globalni sustav (bez negacije jer thrust_local je već reakcijska sila)
	var rotation_matrix = utils.euler_to_rotation_matrix(state.alpha, state.beta, state.gamma)
	var thrust_global = rotation_matrix * thrust_local
	
	return thrust_global

func calculate_thrust_local(state: StateVariables, guidance_input: Vector3, current_time: float) -> Vector3:
	"""
	potisna sila u lokalnom sustavu, bez transformacije.
	Koristi se za kalkulaciju momenta.
	Koristi active_ varijable koje su već prošle kroz latency sustav.
	"""
	if not rocket_data:
		return Vector3.ZERO
	
	# Koristi aktivne inpute (već prošli latenciju u Projectile._physics_process)
	var thrust_magnitude = rocket_data.max_thrust * minf(state.active_thrust_input, 1.0)
	
	# Gimbal iz aktivnog inputa
	var gimbal_magnitude = state.active_gimbal_input.length()
	var gimbal_angle = rocket_data.max_thrust_angle * gimbal_magnitude
	var gimbal_azimuth = atan2(state.active_gimbal_input.y, state.active_gimbal_input.x)
	
	# limit na maksimalni kut
	gimbal_angle = min(gimbal_angle, rocket_data.max_thrust_angle)
	
	# Reakcijska sila potiska u lokalnom sustavu
	var thrust_local = thrust_magnitude * Vector3(
		cos(gimbal_angle),
		sin(gimbal_angle) * cos(gimbal_azimuth),
		sin(gimbal_angle) * sin(gimbal_azimuth)
	)
	
	return thrust_local

func calculate_drag(state: StateVariables) -> Vector3:
	"""
	aerodinamička sila otpora u Model koordinatama.
	relativna brzina računa se: v_rel = v_proj - v_wind
	Wind funkcija vraća vjetar u Godot koordinatama, treba konvertirati u Model koordinate.
	"""
	if not rocket_data or not environment or not utils:
		return Vector3.ZERO
	
	# relativna brzina
	# Pozicija za wind lookup treba biti u Godot koordinatama
	var position_godot = Utils.model_to_godot(state.position)
	var wind_velocity_godot = environment.get_wind_at_position(position_godot)
	# Konvertiraj wind u Model koordinate
	var wind_velocity = Utils.godot_to_model(wind_velocity_godot)
	var v_rel = state.velocity - wind_velocity
	var v_rel_mag = v_rel.length()
	
	# ako je brzina vrlo mala, nema draga
	if v_rel_mag < 0.1:
		return Vector3.ZERO
	
	# smjer projektila
	var direction = utils.get_direction_vector(state.alpha, state.beta, state.gamma)
	
	# kut između smjera i relativne brzine
	var v_rel_unit = v_rel / v_rel_mag
	var cos_theta = direction.dot(v_rel_unit)
	var sin_theta = sqrt(1.0 - cos_theta * cos_theta)
	
	# projekcijska površina
	var R = rocket_data.radius
	var H = rocket_data.cylinder_height
	var h = rocket_data.cone_height
	var A_proj = PI * R * R * abs(cos_theta) + R * (2.0 * H + h) * abs(sin_theta)
	
	# Reynoldsov broj
	var L = 2.0 * R
	var _Re = environment.air_density * v_rel_mag * L / environment.air_viscosity
	
	# koeficijent otpora
	var C_D = rocket_data.drag_coefficient_form + (rocket_data.drag_coefficient_viscous_factor * environment.air_viscosity) / (environment.air_density * v_rel_mag * L)
	
	# drag force
	var drag_mag = 0.5 * environment.air_density * C_D * A_proj * v_rel_mag * v_rel_mag
	var drag_force = -0.5 * environment.air_density * C_D * A_proj * v_rel_mag * v_rel
	
	# limiter - drag ne smije preći 50% max potiska
	var max_drag = 0.5 * rocket_data.max_thrust
	if drag_mag > max_drag:
		drag_force = drag_force.normalized() * max_drag
	
	return drag_force

# UKUPNA SILA

func calculate_total(state: StateVariables, guidance_input: Vector3, current_time: float) -> Vector3:
	"""kombinira sve vanjske sile."""
	var f_gravity = calculate_gravity(state)
	var f_buoyancy = calculate_buoyancy(state)
	var f_thrust = calculate_thrust(state, guidance_input, current_time)
	var f_drag = calculate_drag(state)
	
	return f_gravity + f_buoyancy + f_thrust + f_drag

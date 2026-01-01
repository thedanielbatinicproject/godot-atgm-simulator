extends Node3D
class_name Projectile

# KONFIGURACIJA
@export var scenario_data: Resource
@export var debug_enabled: bool = false
@export var debug_interval: float = 0.2

# KOMPONENTE SIMULACIJE
var state: StateVariables
var forces: Forces
var moments: Moments
var guidance: Guidance
var environment: ModelEnvironment
var utils: Utils

# POMOĆNE VARIJABLE
var elapsed_time: float = 0.0
var debug_timer: float = 0.0

# INICIJALIZACIJA

func _ready():
	"""inicijalizira sve komponente projektila iz scenarija."""
	if not scenario_data:
		print("ERROR: No ScenarioData assigned to Projectile!")
		return
	
	var rocket_data = scenario_data.rocket_data
	if not rocket_data:
		print("ERROR: ScenarioData has no RocketData!")
		return
	
	# inicijalizira environment i utils prvo
	environment = ModelEnvironment.new(scenario_data.wind_function, 
	                                    scenario_data.air_density, 
	                                    scenario_data.gravity)
	utils = Utils.new(rocket_data)
	
	# sada inicijalizira komponente koje trebaju environment i utils
	state = StateVariables.new(rocket_data)
	forces = Forces.new(rocket_data, environment, utils)
	moments = Moments.new(rocket_data, environment, utils)
	guidance = Guidance.new()
	
	scenario_data.setup_wind_for_scenario()
	environment.set_wind_function(scenario_data.wind_function)
	
	var initial_state = scenario_data.get_initial_state()
	state.position = initial_state["position"]
	state.velocity = initial_state["velocity"]
	state.alpha = initial_state["alpha"]
	state.beta = initial_state["beta"]
	state.gamma = initial_state["gamma"]
	elapsed_time = 0.0

	print(rocket_data.get_info())
	print(state.get_state_info())
	print(guidance.get_input_info())
	print(environment.get_environment_info())
	print(scenario_data.get_info())

# SIMULACIJSKA PETLJA

func _physics_process(delta: float):
	"""glavna simulacijska petlja - eksplicitni Euler."""
	if not scenario_data or not scenario_data.rocket_data or not state:
		return
	
	elapsed_time += delta
	var rocket_data = scenario_data.rocket_data
	
	# ========== TRANSLACIJA ==========
	
	# Izračunaj sve vanjske sile (globalni sustav)
	var current_guidance = guidance.get_control_input()
	var f_total = forces.calculate_total(state, current_guidance, elapsed_time)
	
	# Akceleracija centra mase: a = F / M
	var acceleration = f_total / rocket_data.mass
	
	# Ažuriranje brzine: v(k+1) = v(k) + a(k)*Delta t
	state.velocity = state.velocity + acceleration * delta
	
	# Ažuriranje pozicije: r(k+1) = r(k) + v(k)*Delta t (koristi STARU brzinu)
	state.position = state.position + state.velocity * delta
	
	# ========== ROTACIJA ==========
	
	# Izračunaj lokalnu silu potiska (trebam je za moment)
	var thrust_local = forces.calculate_thrust_local(state, current_guidance, elapsed_time)
	
	# Izračunaj sve momente (lokalni sustav)
	var m_total = moments.calculate_total(state, thrust_local)
	
	# Eulerove jednadžbe za kutnu brzinu (diskretne)
	# Momente tromosti
	var I_x = rocket_data.moment_of_inertia_xx
	var I_y = rocket_data.moment_of_inertia_yy
	var I_z = rocket_data.moment_of_inertia_yy  # I_zz = I_yy (simetrija)
	
	# Sigurnosne provjere za momente tromosti
	if I_x <= 0.0 or I_y <= 0.0 or I_z <= 0.0:
		if debug_enabled:
			push_error("ERROR: Moment of inertia is zero or negative!")
		return
	
	var omega_x = state.angular_velocity.x
	var omega_y = state.angular_velocity.y
	var omega_z = state.angular_velocity.z
	
	var M_x = m_total.x
	var M_y = m_total.y
	var M_z = m_total.z
	
	# Komponente kutne akceleracije prema Eulerovim jednadžbama
	# omega_x_dot = M_x/I_x - (I_z - I_y)/I_x * omega_y * omega_z
	var omega_x_dot = (M_x / I_x) - ((I_z - I_y) / I_x) * omega_y * omega_z
	var omega_y_dot = (M_y / I_y) - ((I_x - I_z) / I_y) * omega_z * omega_x
	var omega_z_dot = (M_z / I_z) - ((I_y - I_x) / I_z) * omega_x * omega_y
	
	# Ažuriranje kutne brzine: omega(k+1) = omega(k) + omega_dot(k)*Delta t
	state.angular_velocity.x = omega_x + omega_x_dot * delta
	state.angular_velocity.y = omega_y + omega_y_dot * delta
	state.angular_velocity.z = omega_z + omega_z_dot * delta
	
	# ========== EULEROVI KUTOVI ==========
	
	# Derivacije Eulerovih kutova iz kutne brzine
	var sin_alpha = sin(state.alpha)
	var cos_alpha = cos(state.alpha)
	var tan_beta = tan(state.beta)
	var cos_beta = cos(state.beta)
	
	# Zaštita od singularnosti pri cos(beta) = 0
	var alpha_dot = omega_x + tan_beta * (omega_y * sin_alpha + omega_z * cos_alpha)
	var beta_dot = omega_y * cos_alpha - omega_z * sin_alpha
	var gamma_dot = 0.0
	
	if abs(cos_beta) > 0.001:  # zaštita od singularnosti
		gamma_dot = (omega_y * sin_alpha + omega_z * cos_alpha) / cos_beta
	else:
		if debug_enabled:
			push_warning("WARNING: cos(β) ≈ 0 - singularnost u γ jednadžbi. γ se neće ažurirati.")
	
	# Ažuriranje Eulerovih kutova: theta(k+1) = theta(k) + theta_dot(k)*Δt
	state.alpha = state.alpha + alpha_dot * delta
	state.beta = state.beta + beta_dot * delta
	state.gamma = state.gamma + gamma_dot * delta
	
	# ========== DEBUG ISPIS ==========
	
	if debug_enabled:
		debug_timer += delta
		if debug_timer >= debug_interval:
			debug_timer = 0.0
			_print_debug_info(acceleration, f_total, m_total)

func _print_debug_info(acceleration: Vector3, f_total: Vector3, m_total: Vector3):
	"""Ispisuje trenutno stanje simulacije."""
	var separator = "=".repeat(80)
	print("\n" + separator)
	print("[SIMULACIJA] t=%.3f s" % elapsed_time)
	print(separator)
	
	print("POZICIJA:")
	print("  r = [%.2f, %.2f, %.2f] m" % [state.position.x, state.position.y, state.position.z])
	
	print("BRZINA:")
	print("  v = [%.2f, %.2f, %.2f] m/s (|v| = %.2f)" % [state.velocity.x, state.velocity.y, state.velocity.z, state.velocity.length()])
	
	print("AKCELERACIJA:")
	print("  a = [%.2f, %.2f, %.2f] m/s² (|a| = %.2f)" % [acceleration.x, acceleration.y, acceleration.z, acceleration.length()])
	
	print("SILE:")
	print("  F_tot = [%.2f, %.2f, %.2f] N (|F| = %.2f)" % [f_total.x, f_total.y, f_total.z, f_total.length()])
	
	print("ORIJENTACIJA (Eulerovi kutovi):")
	print("  α = %.2f° | β = %.2f° | γ = %.2f°" % [rad_to_deg(state.alpha), rad_to_deg(state.beta), rad_to_deg(state.gamma)])
	
	print("KUTNA BRZINA:")
	print("  ω = [%.3f, %.3f, %.3f] rad/s (|ω| = %.3f)" % [state.angular_velocity.x, state.angular_velocity.y, state.angular_velocity.z, state.angular_velocity.length()])
	
	print("MOMENTI:")
	print("  M_tot = [%.2f, %.2f, %.2f] N·m (|M| = %.2f)" % [m_total.x, m_total.y, m_total.z, m_total.length()])
	
	var guidance_input = guidance.get_control_input()
	print("UPRAVLJANJE:")
	print("  u_T = %.3f | u_x = %.3f | u_y = %.3f" % [guidance_input.x, guidance_input.y, guidance_input.z])
	
	print(separator)

# SETTERI ZA UPRAVLJANJE

func set_control_input(throttle: float, gimbal_x: float, gimbal_y: float):
	"""postavlja upravljačke ulaze i ažurira vremenske žigove za latencije."""
	if not guidance or not state:
		return
	
	guidance.set_control_input(throttle, gimbal_x, gimbal_y)
	
	# ažuriramo zadnje ulaze i vrijeme primanja
	state.last_thrust_input = throttle
	state.last_thrust_time = elapsed_time
	state.last_gimbal_input = Vector2(gimbal_x, gimbal_y)
	state.last_gimbal_time = elapsed_time

func set_initial_state(pos: Vector3, vel: Vector3, 
                       alpha: float = 0.0, beta: float = 0.0, gamma: float = 0.0):
	"""postavlja početno stanje projektila."""
	if state:
		state.position = pos
		state.velocity = vel
		state.alpha = alpha
		state.beta = beta
		state.gamma = gamma

func reset():
	"""resetira projektil na početno stanje."""
	if state:
		state.reset()
	if guidance:
		guidance.reset_inputs()

# GETTERI

func get_proj_position() -> Vector3:
	"""vraća trenutnu poziciju projektila."""
	return state.position if state else Vector3.ZERO

func get_velocity() -> Vector3:
	"""vraća trenutnu brzinu projektila."""
	return state.velocity if state else Vector3.ZERO

func get_euler_angles() -> Vector3:
	"""vraća Eulerove kutove (α, β, γ)."""
	return Vector3(state.alpha, state.beta, state.gamma) if state else Vector3.ZERO

func get_direction_vector() -> Vector3:
	"""vraća jedinični vektor smjera projektila."""
	if state and utils:
		return utils.get_direction_vector(state.alpha, state.beta, state.gamma)
	return Vector3(0, 0, 1)

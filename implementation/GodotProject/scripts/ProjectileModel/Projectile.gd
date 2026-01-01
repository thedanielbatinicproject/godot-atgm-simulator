extends Node3D
class_name Projectile

# KONFIGURACIJA
@export var scenario_data: Resource

# KOMPONENTE SIMULACIJE
var state: StateVariables
var forces: Forces
var moments: Moments
var guidance: Guidance
var environment: ModelEnvironment
var utils: Utils

# POMOĆNE VARIJABLE
var elapsed_time: float = 0.0

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
	
	state = StateVariables.new(rocket_data)
	forces = Forces.new(rocket_data, environment)
	moments = Moments.new(rocket_data)
	guidance = Guidance.new()
	environment = ModelEnvironment.new(scenario_data.wind_function, 
	                                    scenario_data.air_density, 
	                                    scenario_data.gravity)
	utils = Utils.new(rocket_data)
	
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
	"""glavna simulacijska petlja."""
	if not scenario_data or not scenario_data.rocket_data:
		return
	
	elapsed_time += delta
	
	# TODO: Implementacija u Fazi 4

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

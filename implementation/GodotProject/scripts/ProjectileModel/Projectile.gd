extends Node3D
class_name Projectile

# ============================================================================
# GODOT KOORDINATNI SUSTAV (NATIVNI)
# ============================================================================
# X = desno, Y = gore, Z = naprijed (nos projektila)
# 
# Eulerovi kutovi:
#   α (alpha) = pitch - rotacija oko X (nos gore/dolje)
#   β (beta)  = yaw   - rotacija oko Y (nos lijevo/desno)
#   γ (gamma) = roll  - rotacija oko Z (rotacija oko nosa)
#
# Momenti tromosti:
#   I_xx = I_yy (veći) - pitch/yaw
#   I_zz (manji) - roll
# ============================================================================

# KONFIGURACIJA
var scenario_data: ScenarioData  # Set via initialize() at runtime
@export var debug_enabled: bool = false
@export var debug_interval: float = 0.5
@export var calculate_moments: bool = true
# Debug opcija: koristi gravitaciju u simulaciji
@export var calculate_gravity: bool = true

# PHYSICS DEBUG - Enable to diagnose runaway velocity/position issues
# Set to true to get detailed frame-by-frame logging when values exceed thresholds
@export var physics_debug_enabled: bool = true
const PHYSICS_DEBUG_VELOCITY_THRESHOLD: float = 500.0  # Log if velocity exceeds this
const PHYSICS_DEBUG_POSITION_THRESHOLD: float = 10000.0  # Log if position exceeds this
const PHYSICS_DEBUG_ACCEL_THRESHOLD: float = 1000.0  # Log if acceleration exceeds this
var _physics_debug_frame_count: int = 0
var _last_position: Vector3 = Vector3.ZERO
var _last_velocity: Vector3 = Vector3.ZERO

# Flag to track initialization
var _initialized: bool = false

# Physics control - can be disabled for cutscenes
var physics_enabled: bool = true

# Signals for cutscene/explosion events
signal exploded(position: Vector3)
signal physics_stopped

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

func normalize_angle(angle: float) -> float:
	"""Normalizira kut u raspon [-π, π]."""
	var normalized = angle
	while normalized > PI:
		normalized -= TAU
	while normalized < -PI:
		normalized += TAU
	return normalized

# ============================================================================
# INICIJALIZACIJA
# ============================================================================

func _ready():
	"""Called when node enters scene tree. Actual initialization happens in initialize()."""
	# If scenario_data was already set (e.g., via initialize() before adding to tree),
	# perform initialization now
	if scenario_data and not _initialized:
		_do_initialize()


func initialize(p_scenario_data: ScenarioData) -> void:
	"""Initialize projectile with scenario data. Call this after instantiating the scene."""
	scenario_data = p_scenario_data
	
	# If already in tree, initialize immediately
	if is_inside_tree():
		_do_initialize()
	# Otherwise, _ready() will call _do_initialize()


func _do_initialize():
	"""Actual initialization logic - sets up all components from scenario data."""
	if _initialized:
		return
	_initialized = true
	
	if not scenario_data:
		push_error("Projectile: No ScenarioData provided!")
		return
	
	var rocket_data = scenario_data.rocket_data
	if not rocket_data:
		push_error("Projectile: ScenarioData has no RocketData!")
		return
	
	# Izračunaj momente tromosti
	rocket_data.compute_inertia()
	print("DEBUG: I_xx=%.6f, I_yy=%.6f, I_zz=%.6f" % [
		rocket_data.moment_of_inertia_xx, 
		rocket_data.moment_of_inertia_yy,
		rocket_data.moment_of_inertia_zz
	])
	
	# Inicijaliziraj komponente
	environment = ModelEnvironment.new(
		scenario_data.wind_function, 
		scenario_data.air_density, 
		scenario_data.gravity
	)
	utils = Utils.new(rocket_data)
	state = StateVariables.new(rocket_data)
	
	# Postavi game_profile referencu u RocketData za read-only prikaz
	rocket_data.set_game_profile(scenario_data.game_profile)
	
	forces = Forces.new(rocket_data, environment, utils, scenario_data.game_profile)
	moments = Moments.new(rocket_data, environment, utils, scenario_data.game_profile)
	guidance = Guidance.new(scenario_data.game_profile)
	
	# Dodaj guidance kao child
	guidance.name = "Guidance"
	add_child(guidance)
	
	# Setup wind
	scenario_data.setup_wind_for_scenario()
	environment.set_wind_function(scenario_data.wind_function)
	
	# Početni uvjeti - koristi basis iz ScenarioData (već ima ispravne inverzije)
	var initial_state = scenario_data.get_initial_state()
	state.position = initial_state["position"]
	state.velocity = initial_state["velocity"]
	state.rotation_basis = initial_state["basis"]

	# Debug opcija: runtime isključenje gravitacije (ne dira config)
	if not calculate_gravity:
		environment.gravity = 0.0

	# Euler kutevi samo za prikaz (izvučeni iz basisa)
	var euler = state.rotation_basis.get_euler(EULER_ORDER_YXZ)
	state.alpha = euler.x
	state.beta = euler.y
	state.gamma = euler.z
	elapsed_time = 0.0

	if debug_enabled:
		print(rocket_data.get_info())
		print(state.get_state_info())

# ============================================================================
# SIMULACIJSKA PETLJA
# ============================================================================

func _physics_process(delta: float):
	"""Glavna simulacijska petlja - eksplicitni Euler."""
	if not _initialized or not scenario_data or not scenario_data.rocket_data or not state:
		return
	
	# Skip physics if disabled (during cutscene/explosion)
	if not physics_enabled:
		return
	
	elapsed_time += delta
	var rocket_data = scenario_data.rocket_data
	
	# ========== LATENCY SUSTAV ==========
	# Only read user input if enabled (disabled during cutscene)
	var current_guidance: Vector3
	if user_input_enabled:
		current_guidance = guidance.get_control_input()
	else:
		# During cutscene: maintain last thrust, keep gimbal neutral
		current_guidance = Vector3(state.active_thrust_input, 0.0, 0.0)
	
	# Ažuriraj pending input
	if abs(state.pending_thrust_input - current_guidance.x) > 0.001:
		state.pending_thrust_input = current_guidance.x
		state.pending_thrust_time = elapsed_time
	
	var new_gimbal = Vector2(current_guidance.y, current_guidance.z)
	if state.pending_gimbal_input.distance_to(new_gimbal) > 0.001:
		state.pending_gimbal_input = new_gimbal
		state.pending_gimbal_time = elapsed_time
	
	# Primijeni nakon latencije (latency dolazi iz GameProfile)
	var game_profile = scenario_data.game_profile
	var thrust_latency = game_profile.thrust_latency if game_profile else 0.01
	var gimbal_latency = game_profile.gimbal_latency if game_profile else 0.02
	
	if elapsed_time - state.pending_thrust_time >= thrust_latency:
		state.active_thrust_input = state.pending_thrust_input
	
	if elapsed_time - state.pending_gimbal_time >= gimbal_latency:
		state.active_gimbal_input = state.pending_gimbal_input
	
	# ========== TRANSLACIJA ==========
	var f_total = forces.calculate_total(state, current_guidance, elapsed_time)
	var acceleration = f_total / rocket_data.mass
	
	# ========== PHYSICS DEBUG - Detect runaway values ==========
	if physics_debug_enabled:
		_physics_debug_frame_count += 1
		var should_log = false
		var reason = ""
		
		# Check for excessive values
		if acceleration.length() > PHYSICS_DEBUG_ACCEL_THRESHOLD:
			should_log = true
			reason += "ACCEL_EXCESSIVE "
		if state.velocity.length() > PHYSICS_DEBUG_VELOCITY_THRESHOLD:
			should_log = true
			reason += "VEL_EXCESSIVE "
		if state.position.length() > PHYSICS_DEBUG_POSITION_THRESHOLD:
			should_log = true
			reason += "POS_EXCESSIVE "
		
		# Check for sudden jumps
		var pos_delta = (state.position - _last_position).length()
		var vel_delta = (state.velocity - _last_velocity).length()
		if pos_delta > 100.0 and _physics_debug_frame_count > 1:
			should_log = true
			reason += "POS_JUMP(%.1f) " % pos_delta
		if vel_delta > 50.0 and _physics_debug_frame_count > 1:
			should_log = true
			reason += "VEL_JUMP(%.1f) " % vel_delta
		
		if should_log:
			# Get individual force components for detailed analysis
			var f_gravity = forces.calculate_gravity(state)
			var f_buoyancy = forces.calculate_buoyancy(state)
			var f_thrust = forces.calculate_thrust(state, current_guidance, elapsed_time)
			var f_drag = forces.calculate_drag(state)
			var f_alignment = forces.calculate_velocity_alignment(state)
			
			print("")
			print("[PHYSICS_DEBUG] Frame %d - %s" % [_physics_debug_frame_count, reason])
			print("  dt=%.6f, elapsed=%.3f" % [delta, elapsed_time])
			print("  Position: [%.1f, %.1f, %.1f] (len=%.1f)" % [state.position.x, state.position.y, state.position.z, state.position.length()])
			print("  Velocity: [%.1f, %.1f, %.1f] (len=%.1f)" % [state.velocity.x, state.velocity.y, state.velocity.z, state.velocity.length()])
			print("  Accel:    [%.1f, %.1f, %.1f] (len=%.1f)" % [acceleration.x, acceleration.y, acceleration.z, acceleration.length()])
			print("  --- FORCE BREAKDOWN ---")
			print("  F_gravity:   [%.1f, %.1f, %.1f] (len=%.1f)" % [f_gravity.x, f_gravity.y, f_gravity.z, f_gravity.length()])
			print("  F_buoyancy:  [%.1f, %.1f, %.1f] (len=%.1f)" % [f_buoyancy.x, f_buoyancy.y, f_buoyancy.z, f_buoyancy.length()])
			print("  F_thrust:    [%.1f, %.1f, %.1f] (len=%.1f)" % [f_thrust.x, f_thrust.y, f_thrust.z, f_thrust.length()])
			print("  F_drag:      [%.1f, %.1f, %.1f] (len=%.1f)" % [f_drag.x, f_drag.y, f_drag.z, f_drag.length()])
			print("  F_alignment: [%.1f, %.1f, %.1f] (len=%.1f) <-- SUSPECT!" % [f_alignment.x, f_alignment.y, f_alignment.z, f_alignment.length()])
			print("  F_total:     [%.1f, %.1f, %.1f] (len=%.1f)" % [f_total.x, f_total.y, f_total.z, f_total.length()])
			print("  --- END FORCES ---")
			print("  Guidance: thrust=%.3f, gimbal=[%.3f, %.3f]" % [current_guidance.x, current_guidance.y, current_guidance.z])
			print("  Angular:  [%.3f, %.3f, %.3f] rad/s" % [state.angular_velocity.x, state.angular_velocity.y, state.angular_velocity.z])
			print("  Rotation basis Z: [%.3f, %.3f, %.3f]" % [state.rotation_basis.z.x, state.rotation_basis.z.y, state.rotation_basis.z.z])
		
		_last_position = state.position
		_last_velocity = state.velocity
	
	# Euler integracija
	state.velocity = state.velocity + acceleration * delta
	state.position = state.position + state.velocity * delta
	
	# ========== ROTACIJA ==========
	var thrust_local = forces.calculate_thrust_local(state, current_guidance, elapsed_time)
	var m_total = Vector3.ZERO
	if calculate_moments:
		m_total = moments.calculate_total(state, thrust_local)
	
	# Momenti tromosti (Godot sustav)
	# I_xx = I_yy (veći, pitch/yaw), I_zz (manji, roll)
	var I_x = rocket_data.moment_of_inertia_xx  # pitch
	var I_y = rocket_data.moment_of_inertia_yy  # yaw (= I_xx)
	var I_z = rocket_data.moment_of_inertia_zz  # roll
	
	if I_x <= 0.0 or I_y <= 0.0 or I_z <= 0.0:
		push_error("ERROR: Invalid moment of inertia!")
		return
	
	# Substeps za stabilnost
	var rotation_substeps = 10
	var sub_dt = delta / float(rotation_substeps)
	
	var M_x = m_total.x  # pitch moment
	var M_y = m_total.y  # yaw moment
	var M_z = m_total.z  # roll moment
	# Trenutna roll brzina
	var omega_z = state.angular_velocity.z
	
	for _substep in range(rotation_substeps):
		var omega_x = state.angular_velocity.x
		var omega_y = state.angular_velocity.y
		
		# Eulerove jednadžbe krutog tijela (u lokalnom sustavu)
		var omega_x_dot = (M_x / I_x) - ((I_z - I_y) / I_x) * omega_y * omega_z
		var omega_y_dot = (M_y / I_y) - ((I_x - I_z) / I_y) * omega_z * omega_x
		var omega_z_dot = (M_z / I_z) - ((I_y - I_x) / I_z) * omega_x * omega_y
		
		state.angular_velocity.x += omega_x_dot * sub_dt
		state.angular_velocity.y += omega_y_dot * sub_dt
		state.angular_velocity.z += omega_z_dot * sub_dt
	
	# Ograničenje kutne brzine (parametar iz RocketData)
	var max_omega = rocket_data.max_angular_velocity
	state.angular_velocity.x = clampf(state.angular_velocity.x, -max_omega, max_omega)
	state.angular_velocity.y = clampf(state.angular_velocity.y, -max_omega, max_omega)
	state.angular_velocity.z = clampf(state.angular_velocity.z, -max_omega, max_omega)
	
	# ========== ROLL KONTROLA S INERCIJOM (EKSPONENCIJALNI DAMPING) ==========
	# Roll koristi akceleraciju i eksponencijalno prigušenje za realističan osjećaj
	# Only read roll input if user input is enabled
	var roll_input = guidance.get_roll_input() if user_input_enabled else 0.0
	var roll_max_speed = game_profile.roll_max_speed if game_profile else 3.0
	var roll_accel = game_profile.roll_acceleration if game_profile else 8.0
	var roll_damp = game_profile.roll_damping if game_profile else 3.0
	
	if abs(roll_input) > 0.01:
		# Input aktivan - primijeni akceleraciju prema ciljnoj brzini
		var target_omega_z = roll_input * roll_max_speed
		var accel_dir = sign(target_omega_z - omega_z)
		omega_z += accel_dir * roll_accel * delta
		# Ograniči na maksimalnu brzinu
		omega_z = clampf(omega_z, -roll_max_speed, roll_max_speed)
	else:
		# Eksponencijalno prigušenje (kao kod thrusta)
		omega_z *= exp(-roll_damp * delta)
		if abs(omega_z) < 0.01:
			omega_z = 0.0
	state.angular_velocity.z = omega_z
	
	# ========== ORIJENTACIJA - DIREKTNA INTEGRACIJA ROTACIJSKE MATRICE ==========
	# Ovo izbjegava gimbal lock problem koji imaju Euler kutovi
	#
	# Kutna brzina je u LOKALNOM sustavu, ali rotira GLOBALNE osi.
	# Transformiramo omega u globalni sustav i primjenjujemo malu rotaciju.
	
	var omega_local = state.angular_velocity
	var omega_global = state.rotation_basis * omega_local
	
	# Mala rotacija: R_new = R_delta * R_old
	# R_delta ≈ I + [ω×] * dt  (za male kuteve)
	var angle = omega_global.length() * delta
	if angle > 0.0001:
		var axis = omega_global.normalized()
		var delta_rotation = Basis(axis, angle)
		state.rotation_basis = delta_rotation * state.rotation_basis
	
	# Renormalizacija (numerička stabilnost - Gram-Schmidt)
	var z_axis = state.rotation_basis.z.normalized()
	var y_axis = state.rotation_basis.y
	y_axis = (y_axis - z_axis * y_axis.dot(z_axis)).normalized()
	var x_axis = y_axis.cross(z_axis)
	state.rotation_basis = Basis(x_axis, y_axis, z_axis)
	
	# Izvuci Euler kutove IZ MATRICE (samo za debug/prikaz)
	# Ovo je "read-only" - ne koristimo ih za integraciju
	state.alpha = asin(-state.rotation_basis.z.y)  # pitch
	state.beta = atan2(state.rotation_basis.z.x, state.rotation_basis.z.z)  # yaw
	state.gamma = atan2(state.rotation_basis.x.y, state.rotation_basis.y.y)  # roll
	
	# ========== AŽURIRANJE SCENE ==========
	# NEMA KONVERZIJE - sve je već u Godot koordinatama!
	position = state.position
	basis = state.rotation_basis
	
	# ========== DEBUG ==========
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


# ============================================================================
# CUTSCENE / EXPLOSION CONTROL
# ============================================================================

# Flag to track if user input is disabled (for cutscenes)
var user_input_enabled: bool = true


func disable_user_input() -> void:
	"""Disable user input - physics continues but player can't control.
	Used during final cutscene while projectile flies to target."""
	user_input_enabled = false
	# Reset guidance inputs to neutral
	if guidance:
		guidance.reset_inputs()
	print("[Projectile] User input disabled for cutscene")


func enable_user_input() -> void:
	"""Re-enable user input."""
	user_input_enabled = true


func stop_physics() -> void:
	"""Stop all physics calculations - used during cutscene."""
	physics_enabled = false
	physics_stopped.emit()
	print("[Projectile] Physics stopped for cutscene")


func resume_physics() -> void:
	"""Resume physics calculations."""
	physics_enabled = true


func trigger_explosion() -> void:
	"""Trigger explosion - stop physics, hide mesh, emit signal."""
	stop_physics()
	
	# Hide all visual children (meshes)
	_hide_visual_meshes()
	
	# Emit explosion signal with current position
	var explosion_pos = global_position
	exploded.emit(explosion_pos)
	print("[Projectile] Explosion triggered at: ", explosion_pos)


func _hide_visual_meshes() -> void:
	"""Hide all MeshInstance3D and CSG children (visual representation)."""
	for child in get_children():
		if child is MeshInstance3D or child is CSGShape3D:
			child.visible = false
		# Also check grandchildren
		for grandchild in child.get_children():
			if grandchild is MeshInstance3D or grandchild is CSGShape3D:
				grandchild.visible = false

func show_visual_meshes() -> void:
	"""Show all visual meshes again (for reset/retry)."""
	for child in get_children():
		if child is MeshInstance3D or child is CSGShape3D:
			child.visible = true
		for grandchild in child.get_children():
			if grandchild is MeshInstance3D or grandchild is CSGShape3D:
				grandchild.visible = true


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

extends Node

# ============================================================================
# SCENARIO MANAGER (SINGLETON)
# ============================================================================
# This script's process_mode is set to ALWAYS in _ready() to handle pause input# Main orchestrator for scenario lifecycle, integrating all sub-managers.
# Add to Project Settings -> Autoload as "ScenarioManager"
# ============================================================================

# Preload sub-manager scripts for type safety
const ScenarioStateClass = preload("res://scripts/ScenarioManager/ScenarioState.gd")
const ScenarioLoaderClass = preload("res://scripts/ScenarioManager/ScenarioLoader.gd")
const ScenarioEnvironmentClass = preload("res://scripts/ScenarioManager/ScenarioEnvironment.gd")
const ScenarioEventWatcherClass = preload("res://scripts/ScenarioManager/ScenarioEventWatcher.gd")
const ScenarioCutsceneManagerClass = preload("res://scripts/ScenarioManager/ScenarioCutsceneManager.gd")
const NarratorManagerClass = preload("res://scripts/ScenarioManager/NarratorManager.gd")
const CameraManagerClass = preload("res://scripts/ScenarioManager/CameraManager.gd")
const TankMovementControllerClass = preload("res://scripts/ScenarioManager/TankMovementController.gd")

signal scenario_loading_started
signal scenario_started
signal scenario_paused
signal scenario_resumed
signal scenario_completed(success: bool)
signal player_control_changed(enabled: bool)

# Sub-managers
var state
var loader
var environment
var event_watcher
var cutscene_manager
var narrator
var camera_manager
var tank_movement: TankMovementController = null

# Audio system
var _propulsor_player: AudioStreamPlayer = null
var _beep_player: AudioStreamPlayer = null
var _explosion_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _fail_sfx_player: AudioStreamPlayer = null
var _tank_sound_player: AudioStreamPlayer3D = null  # 3D for doppler effect
var _camera_switch_player: AudioStreamPlayer = null  # Camera type switch sound

# Audio assets
const SFX_PROPULSOR_LOOP = preload("res://assets/Audio/SIM_SFX/PropulsorLoop.wav")
const SFX_HUD_BEEP = preload("res://assets/Audio/SIM_SFX/HUDBeep.wav")
const SFX_EXPLOSION = preload("res://assets/Audio/SIM_SFX/MissleExplosion.wav")
const SFX_FAIL = preload("res://assets/Audio/SIM_SFX/FailSfx.wav")
const SFX_TANK_DRIVING = preload("res://assets/Audio/SIM_SFX/tank_driving.wav")
const SFX_CAMERA_SWITCH = preload("res://assets/Audio/SIM_SFX/cam_sw.wav")
const MUSIC_MAIN_MENU = preload("res://assets/Audio/Music/main_menu1.wav")

# Tank audio state
const TANK_BASE_SPEED_KMH: float = 25.0  # Base speed for default pitch/volume
const TANK_AUDIO_RANGE: float = 1000.0  # Distance at which tank sound is audible (increased for long range)
var _tank_last_position: Vector3 = Vector3.ZERO

# Audio state
var _beep_timer: float = 0.0
var _current_beep_interval: float = 1.5  # Starting interval
var _initial_distance_for_audio: float = 0.0
var _audio_initialized: bool = false

# Mission stats for success screen
var _mission_start_time: float = 0.0
var _mission_end_time: float = 0.0
var _max_velocity_reached: float = 0.0
var _total_distance_traveled: float = 0.0
var _last_projectile_position: Vector3 = Vector3.ZERO

# Cursor state for simulation (hide when using joystick)
var _using_joystick_in_sim: bool = false
var _last_mouse_time_sim: float = 0.0
var _last_joystick_time_sim: float = 0.0
const JOYSTICK_DEADZONE_SIM: float = 0.15

# Current scenario data
var current_scenario_data: ScenarioData = null
var _scenario_root: Node = null
var _hud_layer: CanvasLayer = null
var _pause_menu: Control = null

# Configuration
@export var pause_menu_scene: PackedScene
@export var hud_scene: PackedScene
@export var end_screen_scene: PackedScene


func _ready() -> void:
	# Allow this node to process input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initialize sub-managers
	state = ScenarioStateClass.new()
	
	loader = ScenarioLoaderClass.new()
	add_child(loader)
	
	environment = ScenarioEnvironmentClass.new()
	add_child(environment)
	
	event_watcher = ScenarioEventWatcherClass.new()
	add_child(event_watcher)
	
	cutscene_manager = ScenarioCutsceneManagerClass.new()
	add_child(cutscene_manager)
	
	narrator = NarratorManagerClass.new()
	add_child(narrator)
	
	camera_manager = CameraManagerClass.new()
	add_child(camera_manager)
	
	# Connect signals
	_connect_signals()


func _connect_signals() -> void:
	# State changes
	state.state_changed.connect(_on_state_changed)
	
	# Loader signals
	loader.loading_started.connect(_on_loading_started)
	loader.loading_completed.connect(_on_loading_completed)
	loader.loading_failed.connect(_on_loading_failed)
	
	# Event watcher signals
	event_watcher.projectile_hit_tank.connect(_on_projectile_hit_tank)
	event_watcher.projectile_hit_ground.connect(_on_projectile_hit_ground)
	event_watcher.projectile_hit_obstacle.connect(_on_projectile_hit_obstacle)
	event_watcher.projectile_out_of_bounds.connect(_on_projectile_out_of_bounds)
	event_watcher.cutscene_distance_reached.connect(_on_cutscene_distance_reached)
	event_watcher.terrain_cutscene_distance_reached.connect(_on_terrain_cutscene_distance_reached)
	event_watcher.scenario_timeout.connect(_on_scenario_timeout)
	event_watcher.player_control_delay_finished.connect(_on_player_control_delay_finished)
	
	# Cutscene signals
	cutscene_manager.cutscene_finished.connect(_on_cutscene_finished)
	cutscene_manager.hit_animation_finished.connect(_on_hit_animation_finished)
	cutscene_manager.miss_animation_finished.connect(_on_miss_animation_finished)
	cutscene_manager.tank_should_stop.connect(_on_tank_should_stop)

func _input(event: InputEvent) -> void:
	# Handle pause toggle
	if event.is_action_pressed("pause_toggle"):
		if state.is_state(ScenarioStateClass.State.RUNNING):
			pause_scenario()
		elif state.is_state(ScenarioStateClass.State.PAUSED):
			resume_scenario()
	
	# Camera switching - ONLY during RUNNING state (not during cutscene/success/fail)
	if event.is_action_pressed("switch_camera"):
		if state.is_state(ScenarioStateClass.State.RUNNING):
			camera_manager.switch_camera()
	
	# Camera type switching (OPTICAL -> SOUND -> IR -> THERMAL)
	if event.is_action_pressed("camera_type_switch"):
		if state.is_state(ScenarioStateClass.State.RUNNING):
			_cycle_camera_type()
	
	# Track joystick vs mouse input during simulation for cursor hiding
	if state.is_state(ScenarioStateClass.State.RUNNING) or state.is_state(ScenarioStateClass.State.CUTSCENE):
		_handle_simulation_cursor_input(event)


func _cycle_camera_type() -> void:
	"""Cycle to the next camera type and update HUD."""
	if camera_manager:
		camera_manager.cycle_camera_type()
		
		# Play camera switch sound
		if _camera_switch_player:
			_camera_switch_player.play()
		
		# Update HUD
		if _hud_instance and _hud_instance.has_method("update_camera_type"):
			var camera_type_name = camera_manager.get_current_camera_type_name()
			_hud_instance.update_camera_type(camera_type_name)


func _handle_simulation_cursor_input(event: InputEvent) -> void:
	"""Track input device and hide/show cursor during simulation.
	Respects control config options from main menu."""
	
	# Get control config to check enabled input methods
	var control_config: ControlConfig = null
	if current_scenario_data and current_scenario_data.control_config:
		control_config = current_scenario_data.control_config
	
	# If only gamepad is enabled (no mouse/keyboard), always hide cursor
	if control_config:
		var mouse_enabled = control_config.enable_mouse_input
		var gamepad_enabled = control_config.enable_gamepad_input
		
		# If gamepad is enabled and mouse is disabled, always hide cursor in simulation
		if gamepad_enabled and not mouse_enabled:
			if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
				Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			return
	
	# --- Mouse input ---
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# Ignore if joystick was used very recently (prevent false triggers)
		if current_time - _last_joystick_time_sim < 0.1:
			return
		
		_last_mouse_time_sim = current_time
		
		if _using_joystick_in_sim:
			_using_joystick_in_sim = false
			# Show cursor when mouse is used (only if mouse input is enabled)
			if control_config and control_config.enable_mouse_input:
				# During active simulation, we may want to keep cursor hidden
				# But if mouse is the primary input, show it
				pass  # Cursor visibility handled elsewhere
	
	# --- Gamepad input ---
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		# Only process gamepad input if gamepad is enabled
		if control_config and not control_config.enable_gamepad_input:
			return
		
		var x := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
		var y := Input.get_action_strength("pitch_down") - Input.get_action_strength("pitch_up")
		var throttle := Input.get_action_strength("thrust")
		var mag := Vector2(x, y).length()
		
		if mag > JOYSTICK_DEADZONE_SIM or throttle > JOYSTICK_DEADZONE_SIM or event is InputEventJoypadButton:
			_last_joystick_time_sim = Time.get_ticks_msec() / 1000.0
			
			if not _using_joystick_in_sim:
				_using_joystick_in_sim = true
				# Hide cursor when joystick is being used (only if mouse is also enabled)
				# If mouse is disabled, cursor is already hidden
				if control_config and control_config.enable_mouse_input:
					Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _initialize_simulation_cursor() -> void:
	"""Initialize cursor visibility based on control config when simulation starts."""
	# Get control config to check enabled input methods
	var control_config: ControlConfig = null
	if current_scenario_data and current_scenario_data.control_config:
		control_config = current_scenario_data.control_config
	
	if not control_config:
		# Default behavior: show cursor
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	
	var mouse_enabled = control_config.enable_mouse_input
	var gamepad_enabled = control_config.enable_gamepad_input
	
	# If only gamepad is enabled (no mouse), hide cursor at start
	if gamepad_enabled and not mouse_enabled:
		_using_joystick_in_sim = true
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		print("[ScenarioManager] Cursor hidden: gamepad-only control config")
	# If only mouse is enabled (no gamepad), show cursor
	elif mouse_enabled and not gamepad_enabled:
		_using_joystick_in_sim = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("[ScenarioManager] Cursor visible: mouse-only control config")
	# If both are enabled, start with cursor visible (will hide when joystick is used)
	else:
		_using_joystick_in_sim = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("[ScenarioManager] Cursor visible: mixed control config (will hide on joystick use)")


func _process(delta: float) -> void:
	if not state.is_active():
		return
	
	# Process sub-managers
	if state.is_state(ScenarioStateClass.State.RUNNING):
		event_watcher.process(delta)
		narrator.process(delta)
		camera_manager.process(delta)
		# Process tank movement
		if tank_movement:
			tank_movement.process(delta)
		# Update audio (propulsor pitch/volume, beep timing)
		_update_audio(delta)
		# Track mission stats
		_update_mission_stats()
	
	if state.is_state(ScenarioStateClass.State.CUTSCENE):
		# CRITICAL: Keep watching for terrain/tank collision during cutscene!
		# The projectile is still flying and needs collision detection
		event_watcher.process(delta)
		cutscene_manager.process_cutscene(delta)
		camera_manager.process(delta)
		# Continue tank movement during cutscene (until stopped)
		if tank_movement and not tank_movement.is_stopped():
			tank_movement.process(delta)


# ============================================================================
# PUBLIC API
# ============================================================================

func start_scenario(scenario_data: ScenarioData) -> void:
	"""Called from main menu to start a scenario."""
	if state.is_active():
		push_warning("ScenarioManager: Cannot start scenario while another is active")
		return
	
	current_scenario_data = scenario_data
	
	# Load user settings (game profile & controls) - Resources don't have _ready()
	current_scenario_data.load_user_settings()
	
	scenario_loading_started.emit()
	
	# Clear current scene (main menu)
	_clear_current_scene()
	
	# Transition to loading state
	state.transition_to(ScenarioStateClass.State.LOADING)
	
	# Start loading
	loader.start_loading(scenario_data)


func pause_scenario() -> void:
	if not state.can_transition_to(ScenarioStateClass.State.PAUSED):
		return
	
	state.transition_to(ScenarioStateClass.State.PAUSED)
	
	# Pause audio streams immediately (before tree pause)
	_pause_audio()
	
	# Show cursor for pause menu (menu script will handle joystick/mouse switching)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	get_tree().paused = true
	_show_pause_menu()
	scenario_paused.emit()


func resume_scenario() -> void:
	if not state.can_transition_to(ScenarioStateClass.State.RUNNING):
		return
	
	_hide_pause_menu()
	get_tree().paused = false
	state.transition_to(ScenarioStateClass.State.RUNNING)
	
	# Resume audio that was paused
	_resume_audio()
	
	# Hide cursor again if using joystick during simulation
	if _using_joystick_in_sim:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	scenario_resumed.emit()


func exit_scenario() -> void:
	"""Exit current scenario and return to main menu."""
	_cleanup_scenario()
	state.reset()
	
	# Load main menu scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu/MainMenu.tscn")


func get_scenario_time() -> float:
	return event_watcher.get_scenario_time()


func is_player_control_enabled() -> bool:
	return state.is_player_control_enabled() and event_watcher.is_player_control_enabled()


# ============================================================================
# INTERNAL METHODS
# ============================================================================

func _apply_deferred_terrain_alignment() -> void:
	"""Apply terrain alignment to objects that were marked during loading.
	This must be called AFTER the scene is added to the tree so raycasts work."""
	if not _scenario_root:
		return
	
	# Find all nodes that need terrain alignment
	var nodes_to_align = _find_nodes_needing_alignment(_scenario_root)
	
	if nodes_to_align.is_empty():
		print("[ScenarioManager] No nodes require terrain alignment")
		return
	
	# Get the physics space state from the world (use first Node3D that needs alignment)
	var space_state: PhysicsDirectSpaceState3D = null
	for node in nodes_to_align:
		if node.get_world_3d():
			space_state = node.get_world_3d().direct_space_state
			break
	
	if not space_state:
		push_error("[ScenarioManager] Could not get physics space state for terrain alignment")
		return
	
	print("[ScenarioManager] Applying terrain alignment to %d nodes" % nodes_to_align.size())
	
	for node in nodes_to_align:
		var terrain_result = loader.raycast_terrain(node.global_position, space_state)
		if terrain_result.hit:
			# Align to terrain normal
			loader.align_to_terrain_normal(node, terrain_result.normal)
			# Adjust Y position to terrain height
			node.global_position.y = terrain_result.position.y
			print("[ScenarioManager]   Aligned '%s' to terrain at Y=%.2f" % [node.name, terrain_result.position.y])
		else:
			push_warning("[ScenarioManager]   Failed to raycast terrain for '%s'" % node.name)
		
		# Clear the meta flag
		node.remove_meta("needs_terrain_alignment")


func _find_nodes_needing_alignment(root: Node) -> Array[Node3D]:
	"""Recursively find all Node3D nodes that have the needs_terrain_alignment meta flag."""
	var result: Array[Node3D] = []
	
	if root is Node3D and root.has_meta("needs_terrain_alignment") and root.get_meta("needs_terrain_alignment"):
		result.append(root)
	
	for child in root.get_children():
		result.append_array(_find_nodes_needing_alignment(child))
	
	return result


func _setup_tank_movement() -> void:
	"""Setup tank movement controller after scene is in tree."""
	var tank = _scenario_root.get_node_or_null("Tank")
	if not tank or not tank is Node3D:
		push_warning("[ScenarioManager] Tank node not found for movement setup")
		return
	
	# CRITICAL: Set path data as meta on tank node BEFORE creating controller
	# The TankMovementController reads this data from the tank's meta
	if current_scenario_data:
		tank.set_meta("tank_path_positions_2d", current_scenario_data.tank_path_positions)
		tank.set_meta("tank_path_speeds", current_scenario_data.tank_path_speeds)
		tank.set_meta("tank_initial_delay", current_scenario_data.tank_initial_delay)
		
		print("[ScenarioManager] Tank path data set:")
		print("  - Path positions: %d points" % current_scenario_data.tank_path_positions.size())
		for i in range(current_scenario_data.tank_path_positions.size()):
			var pos = current_scenario_data.tank_path_positions[i]
			print("    Point %d: (%.1f, %.1f)" % [i, pos.x, pos.y])
		print("  - Path speeds: %s" % str(current_scenario_data.tank_path_speeds))
		print("  - Initial delay: %.1f s" % current_scenario_data.tank_initial_delay)
	else:
		push_error("[ScenarioManager] No scenario data available for tank path!")
		return
	
	# Create tank movement controller
	tank_movement = TankMovementControllerClass.new()
	tank_movement.name = "TankMovementController"
	add_child(tank_movement)
	
	# Setup the controller with tank and scenario root (to find HTerrain)
	tank_movement.setup(tank, _scenario_root)
	
	print("[ScenarioManager] Tank movement controller initialized")


func _clear_current_scene() -> void:
	# Get current scene and free it
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.queue_free()


func _on_loading_started() -> void:
	pass  # Loading screen is handled by loader


func _on_loading_completed(scenario_root: Node) -> void:
	_scenario_root = scenario_root
	
	# Create InputManager BEFORE adding scenario_root to tree
	# This ensures it exists when Projectile's _ready() is called
	_create_input_manager()
	
	# Add scenario root to tree (this triggers _ready() on all children)
	get_tree().root.add_child(_scenario_root)
	get_tree().current_scene = _scenario_root
	
	# Now that scene is in tree, perform deferred terrain alignment for tanks
	_apply_deferred_terrain_alignment()
	
	# Setup tank movement controller
	_setup_tank_movement()
	
	# Setup environment
	environment.setup_environment(_scenario_root, current_scenario_data)
	
	# Create HUD layer
	_create_hud()
	
	# Setup narrator
	if _hud_layer:
		narrator.setup(current_scenario_data, _hud_layer)
	
	# Setup camera manager
	camera_manager.setup(_scenario_root, current_scenario_data)
	
	# Pass scenario root to camera manager for visual effects overlay (on separate layer below HUD)
	camera_manager.set_scenario_root(_scenario_root)
	
	# DEBUG: Print comprehensive loading info
	_debug_print_loaded_scenario()
	
	# Transition to starting state
	state.transition_to(ScenarioStateClass.State.STARTING)
	
	# Start event watching
	event_watcher.start_watching(_scenario_root, current_scenario_data)
	
	# Start tank movement
	if tank_movement:
		tank_movement.start()
	
	# Transition to running (player control depends on delay)
	state.transition_to(ScenarioStateClass.State.RUNNING)
	player_control_changed.emit(false)  # Initially disabled until delay passes
	
	# Initialize cursor state based on control config
	_initialize_simulation_cursor()
	
	# Reset mission stats for new scenario
	_reset_mission_stats()
	
	# Initialize and start audio system
	_initialize_audio()
	
	scenario_started.emit()


func _debug_print_loaded_scenario() -> void:
	"""Print comprehensive debug info about what was loaded."""
	print("")
	print("╔══════════════════════════════════════════════════════════════════╗")
	print("║              SCENARIO MANAGER - LOADING COMPLETE                 ║")
	print("╠══════════════════════════════════════════════════════════════════╣")
	
	# Scenario Info
	print("║ SCENARIO:")
	print("║   Name:        %s" % current_scenario_data.scenario_name)
	print("║   Difficulty:  %s" % current_scenario_data.scenario_difficulty)
	print("║   Description: %s" % current_scenario_data.scenario_description.substr(0, 50))
	
	# Level Info
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ LEVEL:")
	var level_path = current_scenario_data.level_scene.resource_path if current_scenario_data.level_scene else "NULL"
	print("║   Scene:       %s" % level_path)
	
	# Tank Info
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ TANK:")
	var tank_path = current_scenario_data.tank_scene.resource_path if current_scenario_data.tank_scene else "NULL - NO TANK!"
	print("║   Scene:       %s" % tank_path)
	print("║   Name:        %s" % current_scenario_data.tank_name)
	print("║   Path Points: %d (Vector2 X,Z - height from terrain)" % current_scenario_data.tank_path_positions.size())
	print("║   Init Delay:  %.1f s" % current_scenario_data.tank_initial_delay)
	if current_scenario_data.tank_path_positions.size() > 0:
		var first_pos = current_scenario_data.tank_path_positions[0]
		print("║   First Point: (%.1f, %.1f)" % [first_pos.x, first_pos.y])
	
	# Projectile Info
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ PROJECTILE:")
	var proj_path = current_scenario_data.projectile_scene.resource_path if current_scenario_data.projectile_scene else "NULL"
	print("║   Scene:       %s" % proj_path)
	print("║   Position:    (%.1f, %.1f, %.1f)" % [current_scenario_data.initial_position.x, current_scenario_data.initial_position.y, current_scenario_data.initial_position.z])
	print("║   Speed:       %.1f m/s" % current_scenario_data.initial_speed)
	print("║   Pitch (α):   %.2f°" % rad_to_deg(current_scenario_data.initial_pitch_alpha))
	print("║   Yaw (β):     %.2f°" % rad_to_deg(current_scenario_data.initial_yaw_beta))
	print("║   Roll (γ):    %.2f°" % rad_to_deg(current_scenario_data.initial_roll_gamma))
	
	# Rocket Data
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ ROCKET DATA:")
	if current_scenario_data.rocket_data:
		var rd = current_scenario_data.rocket_data
		print("║   Resource:    %s" % rd.resource_path)
		print("║   Name:        %s" % rd.rocket_name)
		print("║   Mass:        %.2f kg" % rd.mass)
		print("║   Radius:      %.3f m" % rd.radius)
		print("║   Cylinder H:  %.3f m" % rd.cylinder_height)
		print("║   Cone H:      %.3f m" % rd.cone_height)
		print("║   Max Thrust:  %.1f N" % rd.max_thrust)
		print("║   Max Gimbal:  %.1f°" % rad_to_deg(rd.max_thrust_angle))
	else:
		print("║   Resource:    NULL - NO ROCKET DATA!")
	
	# Game Profile
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ GAME PROFILE:")
	if current_scenario_data.game_profile:
		var gp = current_scenario_data.game_profile
		print("║   Resource:    %s" % gp.resource_path)
		print("║   Name:        %s" % (gp.profile_name if "profile_name" in gp else "Unknown"))
		if "roll_speed" in gp:
			print("║   Roll Speed:  %.2f rad/s" % gp.roll_speed)
		if "gimbal_sensitivity" in gp:
			print("║   Gimbal Sens: %.2f" % gp.gimbal_sensitivity)
	else:
		print("║   Resource:    NULL - NO GAME PROFILE LOADED!")
	
	# Control Config
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ CONTROL CONFIG:")
	if current_scenario_data.control_config:
		var cc = current_scenario_data.control_config
		print("║   Resource:    %s" % cc.resource_path)
		if "config_name" in cc:
			print("║   Name:        %s" % cc.config_name)
	else:
		print("║   Resource:    NULL - NO CONTROL CONFIG LOADED!")
	
	# Environment
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ ENVIRONMENT:")
	print("║   Time of Day: %.1f h" % current_scenario_data.time_of_day)
	print("║   Fog Density: %.2f" % current_scenario_data.fog_density)
	print("║   Ambient:     %.2f" % current_scenario_data.ambient_light_energy)
	print("║   Air Density: %.4f kg/m³" % current_scenario_data.air_density)
	print("║   Gravity:     %.2f m/s²" % current_scenario_data.gravity)
	print("║   Wind Type:   %s" % current_scenario_data.wind_type)
	
	# Player Controls
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ PLAYER SETTINGS:")
	print("║   Control Delay:     %.1f s" % current_scenario_data.player_control_delay)
	print("║   Cutscene Distance: %.1f m" % current_scenario_data.final_cutscene_start_distance)
	print("║   Max Time:          %.1f s" % current_scenario_data.max_scenario_time)
	print("║   Mission Area:      %.1f m" % current_scenario_data.mission_area_limit)
	print("║   Static Camera:     (%.1f, %.1f, %.1f)" % [current_scenario_data.static_camera_location.x, current_scenario_data.static_camera_location.y, current_scenario_data.static_camera_location.z])
	
	# Loaded Nodes
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ LOADED NODES IN SCENE:")
	var level_node = _scenario_root.get_node_or_null("Level")
	var tank_node = _scenario_root.get_node_or_null("Tank")
	var projectile_node = _scenario_root.get_node_or_null("Projectile")
	var input_mgr_node = _scenario_root.get_node_or_null("InputManager")
	print("║   Level:        %s" % ("✓ LOADED" if level_node else "✗ MISSING"))
	print("║   Tank:         %s" % ("✓ LOADED" if tank_node else "✗ MISSING"))
	print("║   Projectile:   %s" % ("✓ LOADED" if projectile_node else "✗ MISSING"))
	print("║   InputManager: %s" % ("✓ LOADED" if input_mgr_node else "✗ MISSING"))
	print("║   HUD Layer:    %s" % ("✓ CREATED" if _hud_layer else "✗ MISSING"))
	print("║   HUD Instance: %s" % ("✓ CREATED" if _hud_instance else "✗ MISSING"))
	
	# Camera Info
	print("╠──────────────────────────────────────────────────────────────────╣")
	print("║ CAMERA:")
	print("║   Active:      %s" % camera_manager.get_active_camera_name())
	
	print("╚══════════════════════════════════════════════════════════════════╝")
	print("")


func _on_loading_failed(error: String) -> void:
	push_error("ScenarioManager: Loading failed - " + error)
	state.reset()
	
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu/MainMenu.tscn")


func _on_state_changed(old_state: int, new_state: int) -> void:
	print("ScenarioManager: State changed from %s to %s" % [
		ScenarioStateClass.State.keys()[old_state],
		ScenarioStateClass.State.keys()[new_state]
	])


func _on_player_control_delay_finished() -> void:
	if state.is_state(ScenarioStateClass.State.RUNNING):
		player_control_changed.emit(true)
		_set_hud_visible(true)
		# Note: General only speaks when voice lines are defined in scenario data


func _set_hud_visible(visible: bool) -> void:
	"""Show or hide the HUD based on player control state."""
	if _hud_instance:
		_hud_instance.visible = visible


func _set_input_controls_visible(visible: bool) -> void:
	"""Show or hide the input controls (StickController circle/dot)."""
	if _input_manager:
		# Find the UIRoot which contains StickController visuals
		var ui_root = _input_manager.get_node_or_null("UIRoot")
		if ui_root:
			ui_root.visible = visible
		# Also disable/enable controls functionality
		if _input_manager.has_method("set_controls_enabled"):
			_input_manager.set_controls_enabled(visible)


func _on_cutscene_distance_reached() -> void:
	if not state.can_transition_to(ScenarioStateClass.State.CUTSCENE):
		return
	
	# Disable player control and hide HUD and input controls
	player_control_changed.emit(false)
	_set_hud_visible(false)
	_set_input_controls_visible(false)  # Hide circle and dot
	
	# Reset camera to optical for cutscene (remove shader effects)
	camera_manager.reset_to_optical()
	
	# Start cutscene
	state.transition_to(ScenarioStateClass.State.CUTSCENE)
	
	var projectile = event_watcher.get_projectile()
	var tank = event_watcher.get_tank()
	
	# Capture projectile position NOW - this is where camera will freeze
	var projectile_entry_position = projectile.global_position if projectile else Vector3.ZERO
	
	# Disable user input during cutscene - physics simulation continues!
	# The projectile will keep flying until it hits the tank (collision detected)
	if projectile and projectile.has_method("disable_user_input"):
		projectile.disable_user_input()
	
	# Pass projectile entry position for camera placement
	cutscene_manager.start_final_cutscene(projectile, tank, projectile_entry_position)


func _on_terrain_cutscene_distance_reached() -> void:
	"""Called when projectile approaches terrain (about to hit ground)."""
	if not state.can_transition_to(ScenarioStateClass.State.CUTSCENE):
		return
	
	print("[ScenarioManager] Projectile approaching terrain - starting cutscene")
	
	# Disable player control and hide HUD and input controls
	player_control_changed.emit(false)
	_set_hud_visible(false)
	_set_input_controls_visible(false)
	
	# Reset camera to optical for cutscene (remove shader effects)
	camera_manager.reset_to_optical()
	
	# Start cutscene
	state.transition_to(ScenarioStateClass.State.CUTSCENE)
	
	var projectile = event_watcher.get_projectile()
	var tank = event_watcher.get_tank()
	
	# Capture projectile position NOW - this is where camera will freeze
	var projectile_entry_position = projectile.global_position if projectile else Vector3.ZERO
	
	# Disable user input during cutscene
	if projectile and projectile.has_method("disable_user_input"):
		projectile.disable_user_input()
	
	# Pass projectile entry position for camera placement
	cutscene_manager.start_final_cutscene(projectile, tank, projectile_entry_position)


func _on_projectile_hit_tank() -> void:
	"""Called when projectile collides with tank - SUCCESS!"""
	print("[ScenarioManager] Projectile hit tank!")
	
	# IMMEDIATELY play explosion sound and stop simulation audio!
	_stop_simulation_audio()
	_play_explosion_sound()
	
	# Get projectile position for explosion
	var projectile = event_watcher.get_projectile()
	var hit_pos = projectile.global_position if projectile else Vector3.ZERO
	
	# Play hit animation (handles visual explosion and projectile hiding)
	cutscene_manager.play_hit_animation(hit_pos)
	
	# Note: General only speaks when voice lines are defined in scenario data


func _on_projectile_hit_ground(position: Vector3) -> void:
	"""Called when projectile hits ground (misses tank) - FAILURE!"""
	print("[ScenarioManager] Projectile hit ground at: ", position)
	
	# IMMEDIATELY play explosion sound and stop simulation audio!
	_stop_simulation_audio()
	_play_explosion_sound()
	
	# If we're still in RUNNING state, transition to cutscene first
	if state.is_state(ScenarioStateClass.State.RUNNING):
		state.transition_to(ScenarioStateClass.State.CUTSCENE)
		player_control_changed.emit(false)
		_set_hud_visible(false)
		_set_input_controls_visible(false)  # Hide circle and dot
		
		# Reset camera to optical for cutscene (remove shader effects)
		camera_manager.reset_to_optical()
		
		# Disable user input
		var projectile = event_watcher.get_projectile()
		if projectile and projectile.has_method("disable_user_input"):
			projectile.disable_user_input()
		
		# Start cutscene camera - TERRAIN MISS mode (camera looks at impact, not tank)
		var tank = event_watcher.get_tank()
		var entry_pos = projectile.global_position if projectile else position
		var cutscene_dist = current_scenario_data.final_cutscene_start_distance if current_scenario_data else 50.0
		cutscene_manager.start_final_cutscene(projectile, tank, entry_pos, true, position, cutscene_dist)
	
	# Play miss animation (handles explosion and projectile hiding)
	cutscene_manager.play_miss_animation(position)
	
	# Note: General only speaks when voice lines are defined in scenario data


func _on_projectile_hit_obstacle(position: Vector3, obstacle: Node) -> void:
	"""Called when projectile hits an obstacle (layer 2) - FAILURE!"""
	var obstacle_name: String = "Unknown"
	if obstacle:
		obstacle_name = obstacle.name
	print("[ScenarioManager] Projectile hit obstacle '%s' at: %s" % [obstacle_name, position])
	
	# IMMEDIATELY play explosion sound and stop simulation audio!
	_stop_simulation_audio()
	_play_explosion_sound()
	
	# If we're still in RUNNING state, transition to cutscene first
	if state.is_state(ScenarioStateClass.State.RUNNING):
		state.transition_to(ScenarioStateClass.State.CUTSCENE)
		player_control_changed.emit(false)
		_set_hud_visible(false)
		_set_input_controls_visible(false)  # Hide circle and dot
		
		# Reset camera to optical for cutscene (remove shader effects)
		camera_manager.reset_to_optical()
		
		# Disable user input
		var projectile = event_watcher.get_projectile()
		if projectile and projectile.has_method("disable_user_input"):
			projectile.disable_user_input()
		
		# Start cutscene camera - OBSTACLE MISS mode (camera looks at impact, not tank)
		var tank = event_watcher.get_tank()
		var entry_pos = projectile.global_position if projectile else position
		var cutscene_dist = current_scenario_data.final_cutscene_start_distance if current_scenario_data else 50.0
		cutscene_manager.start_final_cutscene(projectile, tank, entry_pos, true, position, cutscene_dist)
	
	# Play miss animation (handles explosion and projectile hiding)
	cutscene_manager.play_miss_animation(position)
	
	# Note: General only speaks when voice lines are defined in scenario data


func _on_tank_should_stop() -> void:
	"""Called when tank should stop (hit by projectile)."""
	if tank_movement:
		tank_movement.stop()
		print("[ScenarioManager] Tank stopped")


func _on_projectile_out_of_bounds() -> void:
	_end_scenario(false, "Projectile left the mission area.")


func _on_scenario_timeout() -> void:
	_end_scenario(false, "Time limit exceeded. Mission failed.")


func _on_cutscene_finished() -> void:
	pass  # Cutscene cleanup handled elsewhere


func _on_hit_animation_finished() -> void:
	# Play end scenario audio (success)
	_play_end_scenario_audio(true)
	# Show success screen while keeping camera active
	_show_end_screen_overlay(true, "Target eliminated! Mission accomplished.")


func _on_miss_animation_finished() -> void:
	# Play end scenario audio (failure)
	_play_end_scenario_audio(false)
	# Show failure screen while keeping camera active
	_show_end_screen_overlay(false, "Projectile missed the target. Tank survived.")


func _show_end_screen_overlay(success: bool, message: String) -> void:
	"""Show success/failure screen as overlay while camera stays active."""
	var target_state = ScenarioStateClass.State.COMPLETED if success else ScenarioStateClass.State.FAILED
	
	if state.can_transition_to(target_state):
		state.transition_to(target_state)
	
	scenario_completed.emit(success)
	
	# Show end screen overlay (camera keeps running!)
	_show_end_screen(success, message)
	
	# Note: Cutscene camera stays active - player can still see the scene
	# Cutscene will be ended when player exits via end screen


func _end_scenario(success: bool, message: String) -> void:
	"""Immediately end scenario (used for timeout, out of bounds, etc.)."""
	var target_state = ScenarioStateClass.State.COMPLETED if success else ScenarioStateClass.State.FAILED
	
	if state.can_transition_to(target_state):
		state.transition_to(target_state)
	
	scenario_completed.emit(success)
	
	# End any running cutscene
	cutscene_manager.end_cutscene()
	
	# Show end screen
	_show_end_screen(success, message)


var _hud_instance: Node = null

func _create_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDLayer"
	_hud_layer.layer = 10
	_scenario_root.add_child(_hud_layer)
	
	# Use preloaded HUD scene
	_hud_instance = HUD_SCENE.instantiate()
	_hud_layer.add_child(_hud_instance)
	# Start with HUD hidden until player control is enabled
	_hud_instance.visible = false
	
	# Preload and add Pause Menu (hidden)
	_pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
	_pause_menu_instance.visible = false
	_hud_layer.add_child(_pause_menu_instance)
	# Connect buttons directly
	_connect_pause_menu_buttons()
	
	# Preload and add Mission Success Screen (hidden)
	_success_screen_instance = MISSION_SUCCESS_SCENE.instantiate()
	_success_screen_instance.visible = false
	_hud_layer.add_child(_success_screen_instance)
	# Connect buttons directly
	_connect_success_screen_buttons()
	
	# Preload and add Mission Failure Screen (hidden)
	_failure_screen_instance = MISSION_FAILURE_SCENE.instantiate()
	_failure_screen_instance.visible = false
	_hud_layer.add_child(_failure_screen_instance)
	# Connect buttons directly
	_connect_failure_screen_buttons()


func _retry_scenario() -> void:
	"""Restart current scenario."""
	if current_scenario_data:
		var scenario_to_retry = current_scenario_data
		_cleanup_scenario()
		state.reset()
		get_tree().paused = false
		# Restart with same scenario
		call_deferred("start_scenario", scenario_to_retry)


var _input_manager: Node = null
const INPUT_MANAGER_SCENE = preload("res://assets/UI/input_manager.tscn")
const HUD_SCENE = preload("res://scenes/UI/HUD.tscn")
const PAUSE_MENU_SCENE = preload("res://scenes/UI/PauseMenu.tscn")
const MISSION_SUCCESS_SCENE = preload("res://scenes/UI/MissionSuccessfulScreen.tscn")
const MISSION_FAILURE_SCENE = preload("res://scenes/UI/MissionFailureScreen.tscn")

# UI instances (preloaded, toggle visibility)
var _pause_menu_instance: Control = null
var _success_screen_instance: Control = null
var _failure_screen_instance: Control = null

func _create_input_manager() -> void:
	# Instantiate InputManager scene and add to scenario
	_input_manager = INPUT_MANAGER_SCENE.instantiate()
	_input_manager.name = "InputManager"
	_scenario_root.add_child(_input_manager)


func _show_pause_menu() -> void:
	if _pause_menu_instance:
		_pause_menu_instance.visible = true
		# Hide other overlays
		if _success_screen_instance:
			_success_screen_instance.visible = false
		if _failure_screen_instance:
			_failure_screen_instance.visible = false

func _hide_pause_menu() -> void:
	if _pause_menu_instance:
		_pause_menu_instance.visible = false


func _show_end_screen(success: bool, reason: String) -> void:
	# Hide pause menu if visible
	if _pause_menu_instance:
		_pause_menu_instance.visible = false
	
	# Record end time
	_mission_end_time = get_scenario_time()
	
	# Show cursor for end screen buttons (menu script will handle joystick/mouse switching)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Show appropriate end screen
	if success:
		if _success_screen_instance:
			_success_screen_instance.visible = true
			# Update success details label
			_update_success_details()
		if _failure_screen_instance:
			_failure_screen_instance.visible = false
	else:
		if _failure_screen_instance:
			_failure_screen_instance.visible = true
			# Update failure reason label - search deeper in hierarchy
			var reason_label = _failure_screen_instance.get_node_or_null("HBoxContainer/BoxContainer2/MarginContainer/FailureReason")
			if reason_label:
				reason_label.text = reason
		if _success_screen_instance:
			_success_screen_instance.visible = false


func _update_success_details() -> void:
	"""Update the success details label with mission stats."""
	if not _success_screen_instance:
		return
	
	var details_label = _success_screen_instance.get_node_or_null("HBoxContainer/BoxContainer2/MarginContainer/SuccessDetails")
	if not details_label:
		return
	
	var mission_time = _mission_end_time
	var minutes = int(mission_time) / 60
	var seconds = fmod(mission_time, 60.0)
	
	# Format: "Time: 1:23.4    Max Speed: 342 m/s    Distance: 1.2 km"
	var time_str = "%d:%05.2f" % [minutes, seconds]
	var speed_str = "%.0f m/s" % _max_velocity_reached
	var dist_str = "%.1f km" % (_total_distance_traveled / 1000.0)
	
	details_label.text = "Time: %s    Max: %s    Dist: %s" % [time_str, speed_str, dist_str]


func _connect_pause_menu_buttons() -> void:
	"""Connect pause menu buttons directly."""
	if not _pause_menu_instance:
		return
	
	# Path: HBoxContainer/BoxContainer3/MarginContainer/HBoxContainer/BoxContainer3/VBoxContainer/ButtonName
	var button_container = _pause_menu_instance.get_node_or_null("HBoxContainer/BoxContainer3/MarginContainer/HBoxContainer/BoxContainer3/VBoxContainer")
	if not button_container:
		push_warning("[ScenarioManager] Could not find pause menu button container")
		return
	
	var resume_btn = button_container.get_node_or_null("Resume")
	var restart_btn = button_container.get_node_or_null("RestartScenario")
	var mainmenu_btn = button_container.get_node_or_null("MainMenu")
	
	if resume_btn:
		resume_btn.pressed.connect(resume_scenario)
	if restart_btn:
		restart_btn.pressed.connect(_retry_scenario)
	if mainmenu_btn:
		mainmenu_btn.pressed.connect(exit_scenario)
	
	print("[ScenarioManager] Pause menu buttons connected")


func _connect_success_screen_buttons() -> void:
	"""Connect success screen buttons directly."""
	if not _success_screen_instance:
		return
	
	var button_container = _success_screen_instance.get_node_or_null("HBoxContainer/BoxContainer3/MarginContainer/HBoxContainer/BoxContainer3/VBoxContainer")
	if not button_container:
		push_warning("[ScenarioManager] Could not find success screen button container")
		return
	
	var restart_btn = button_container.get_node_or_null("RestartScenario")
	var mainmenu_btn = button_container.get_node_or_null("MainMenu")
	
	if restart_btn:
		restart_btn.pressed.connect(_retry_scenario)
	if mainmenu_btn:
		mainmenu_btn.pressed.connect(exit_scenario)
	
	print("[ScenarioManager] Success screen buttons connected")


func _connect_failure_screen_buttons() -> void:
	"""Connect failure screen buttons directly."""
	if not _failure_screen_instance:
		return
	
	var button_container = _failure_screen_instance.get_node_or_null("HBoxContainer/BoxContainer3/MarginContainer/HBoxContainer/BoxContainer3/VBoxContainer")
	if not button_container:
		push_warning("[ScenarioManager] Could not find failure screen button container")
		return
	
	var restart_btn = button_container.get_node_or_null("RestartScenario")
	var mainmenu_btn = button_container.get_node_or_null("MainMenu")
	
	if restart_btn:
		restart_btn.pressed.connect(_retry_scenario)
	if mainmenu_btn:
		mainmenu_btn.pressed.connect(exit_scenario)
	
	print("[ScenarioManager] Failure screen buttons connected")


func _cleanup_scenario() -> void:
	# Stop all sub-managers
	event_watcher.stop_watching()
	cutscene_manager.cleanup()
	narrator.cleanup()
	environment.cleanup()
	camera_manager.cleanup()
	
	# Cleanup audio
	_cleanup_audio()
	
	# Cleanup tank movement controller
	if tank_movement:
		tank_movement.queue_free()
		tank_movement = null
	
	# Unload scenario
	loader.unload_scenario()
	
	# Clean up HUD and UI instances
	if _hud_layer:
		_hud_layer.queue_free()
		_hud_layer = null
	
	_hud_instance = null
	_pause_menu_instance = null
	_success_screen_instance = null
	_failure_screen_instance = null
	_scenario_root = null
	current_scenario_data = null


# ============================================================================
# AUDIO SYSTEM
# ============================================================================

func _initialize_audio() -> void:
	"""Initialize audio players when simulation starts."""
	print("[ScenarioManager] Initializing audio system...")
	
	# Create propulsor loop player
	_propulsor_player = AudioStreamPlayer.new()
	_propulsor_player.name = "PropulsorPlayer"
	_propulsor_player.stream = SFX_PROPULSOR_LOOP
	_propulsor_player.volume_db = -5.0  # Start at idle volume
	_propulsor_player.pitch_scale = 0.8  # Start at lower pitch
	_propulsor_player.bus = "SFX"  # Always use SFX bus
	add_child(_propulsor_player)
	_propulsor_player.play()
	# Loop the propulsor sound
	_propulsor_player.finished.connect(_on_propulsor_loop_finished)
	
	# Create beep player
	_beep_player = AudioStreamPlayer.new()
	_beep_player.name = "BeepPlayer"
	_beep_player.stream = SFX_HUD_BEEP
	_beep_player.volume_db = -8.0  # Lowered - beep is subtle background audio
	_beep_player.bus = "SFX"  # Always use SFX bus
	add_child(_beep_player)
	
	# Create explosion player
	_explosion_player = AudioStreamPlayer.new()
	_explosion_player.name = "ExplosionPlayer"
	_explosion_player.stream = SFX_EXPLOSION
	_explosion_player.volume_db = 0.0
	_explosion_player.bus = "SFX"  # Always use SFX bus
	add_child(_explosion_player)
	
	# Create fail SFX player
	_fail_sfx_player = AudioStreamPlayer.new()
	_fail_sfx_player.name = "FailSfxPlayer"
	_fail_sfx_player.stream = SFX_FAIL
	_fail_sfx_player.volume_db = 0.0
	_fail_sfx_player.bus = "SFX"  # Always use SFX bus
	add_child(_fail_sfx_player)
	
	# Create camera switch sound player
	_camera_switch_player = AudioStreamPlayer.new()
	_camera_switch_player.name = "CameraSwitchPlayer"
	_camera_switch_player.stream = SFX_CAMERA_SWITCH
	_camera_switch_player.volume_db = 0.0
	_camera_switch_player.bus = "SFX"
	add_child(_camera_switch_player)
	
	# Create tank driving sound (3D for doppler effect)
	_initialize_tank_audio()
	
	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.stream = MUSIC_MAIN_MENU
	_music_player.volume_db = -6.0
	_music_player.bus = "Music"  # Always use Music bus
	add_child(_music_player)
	
	# Get initial distance for beep calculations
	var projectile = event_watcher.get_projectile()
	var tank = event_watcher.get_tank()
	if projectile and tank:
		_initial_distance_for_audio = projectile.global_position.distance_to(tank.global_position)
	else:
		_initial_distance_for_audio = 1000.0  # Default
	
	_beep_timer = 0.0
	_current_beep_interval = 1.5
	_audio_initialized = true
	
	# Play first beep immediately
	_beep_player.play()
	
	print("[ScenarioManager] Audio initialized. Initial distance: %.1fm" % _initial_distance_for_audio)


func _on_propulsor_loop_finished() -> void:
	"""Loop the propulsor sound while active."""
	if _propulsor_player and state.is_state(ScenarioStateClass.State.RUNNING):
		_propulsor_player.play()


func _pause_audio() -> void:
	"""Instantly pause all audio streams when game is paused."""
	if not _audio_initialized:
		return
	
	# Use stream_paused to instantly freeze audio (not stop)
	if _propulsor_player:
		_propulsor_player.stream_paused = true
	if _beep_player:
		_beep_player.stream_paused = true
	if _tank_sound_player:
		_tank_sound_player.stream_paused = true


func _resume_audio() -> void:
	"""Resume audio after unpausing."""
	if not _audio_initialized:
		return
	
	# Unpause the streams
	if _propulsor_player:
		_propulsor_player.stream_paused = false
		# If it somehow stopped, restart it
		if not _propulsor_player.playing:
			_propulsor_player.play()
	if _beep_player:
		_beep_player.stream_paused = false
	if _tank_sound_player:
		_tank_sound_player.stream_paused = false


func _reset_mission_stats() -> void:
	"""Reset mission stats at the start of a new scenario."""
	_mission_start_time = 0.0
	_mission_end_time = 0.0
	_max_velocity_reached = 0.0
	_total_distance_traveled = 0.0
	_last_projectile_position = Vector3.ZERO


func _update_mission_stats() -> void:
	"""Track mission stats: max velocity and total distance traveled."""
	var projectile = event_watcher.get_projectile()
	if not projectile:
		return
	
	# Track max velocity
	var current_velocity = projectile.state.velocity.length() if projectile.state else 0.0
	if current_velocity > _max_velocity_reached:
		_max_velocity_reached = current_velocity
	
	# Track distance traveled
	var current_pos = projectile.global_position
	if _last_projectile_position != Vector3.ZERO:
		_total_distance_traveled += _last_projectile_position.distance_to(current_pos)
	_last_projectile_position = current_pos


func _update_audio(delta: float) -> void:
	"""Update audio based on thrust and distance."""
	if not _audio_initialized:
		return
	
	# Update propulsor pitch/volume based on thrust
	_update_propulsor_audio()
	
	# Update beep timing based on distance
	_update_beep_audio(delta)
	
	# Update tank driving sound
	_update_tank_audio(delta)


func _update_propulsor_audio() -> void:
	"""Update propulsor pitch and volume based on thrust input."""
	if not _propulsor_player:
		return
	
	var projectile = event_watcher.get_projectile()
	if not projectile or not projectile.guidance:
		return
	
	var throttle = projectile.guidance.throttle_input  # 0 to 1
	
	# Pitch: 0.8 at no thrust, 1.2 at full thrust
	var target_pitch = lerpf(0.8, 1.2, throttle)
	_propulsor_player.pitch_scale = target_pitch
	
	# Volume: -5dB at no thrust, +2dB at full thrust (raised overall)
	var target_volume = lerpf(-5.0, 2.0, throttle)
	_propulsor_player.volume_db = target_volume


func _update_beep_audio(delta: float) -> void:
	"""Update beep interval based ONLY on distance between projectile and tank.
	Smaller distance = faster beep, larger distance = slower beep.
	- At starting distance: 0.5 BPS (2.0s interval)
	- At <50m from tank: 12 BPS (0.083s interval)
	- At >1.5x starting distance: 0.2 BPS (5.0s interval)"""
	if not _beep_player:
		return
	
	var projectile = event_watcher.get_projectile()
	var tank = event_watcher.get_tank()
	if not projectile or not tank:
		return
	
	# ONLY factor: straight-line distance between projectile and tank
	var projectile_pos = projectile.global_position
	var tank_pos = tank.global_position
	var current_distance = projectile_pos.distance_to(tank_pos)
	
	# Distance thresholds
	const CLOSE_DISTANCE = 50.0  # 12 BPS at this distance or closer
	var start_distance = _initial_distance_for_audio  # 0.5 BPS at starting distance
	var far_distance = start_distance * 1.5  # 0.2 BPS beyond this
	
	# Interval values (seconds between beeps)
	const MIN_INTERVAL = 1.0 / 12.0  # 12 BPS = 0.083s (closest)
	const START_INTERVAL = 1.0 / 0.5  # 0.5 BPS = 2.0s (at start)
	const MAX_INTERVAL = 1.0 / 0.2   # 0.2 BPS = 5.0s (furthest)
	
	# Calculate interval based purely on distance
	if current_distance <= CLOSE_DISTANCE:
		# Very close - fastest beeping
		_current_beep_interval = MIN_INTERVAL
	elif current_distance >= far_distance:
		# Very far - slowest beeping
		_current_beep_interval = MAX_INTERVAL
	elif current_distance >= start_distance:
		# Between start and 1.5x start - linear slowdown
		var t = (current_distance - start_distance) / (far_distance - start_distance)
		_current_beep_interval = lerpf(START_INTERVAL, MAX_INTERVAL, t)
	else:
		# Between 50m and start distance - exponential speedup as distance decreases
		var t = (current_distance - CLOSE_DISTANCE) / (start_distance - CLOSE_DISTANCE)
		# t=0 at 50m (fastest), t=1 at start distance (0.5 BPS)
		# Use cubic curve for dramatic speedup when close
		var exp_t = pow(t, 2.5)
		_current_beep_interval = lerpf(MIN_INTERVAL, START_INTERVAL, exp_t)
	
	# Update timer and play beep when interval reached
	_beep_timer += delta
	if _beep_timer >= _current_beep_interval:
		_beep_timer = 0.0
		# Always restart the beep - don't wait for it to finish!
		# This allows rapid beeping at high BPS rates
		_beep_player.stop()  # Stop current beep if playing
		_beep_player.play()  # Start new beep immediately


func _initialize_tank_audio() -> void:
	"""Initialize 3D audio player for tank driving sound with doppler effect."""
	var tank = event_watcher.get_tank() if event_watcher else null
	if not tank:
		return
	
	_tank_sound_player = AudioStreamPlayer3D.new()
	_tank_sound_player.name = "TankDrivingSound"
	_tank_sound_player.stream = SFX_TANK_DRIVING
	_tank_sound_player.bus = "SFX"
	_tank_sound_player.volume_db = 0.0  # Base volume at 25 km/h
	_tank_sound_player.pitch_scale = 1.0  # Base pitch at 25 km/h
	_tank_sound_player.max_distance = TANK_AUDIO_RANGE
	_tank_sound_player.unit_size = 10.0  # How quickly volume falls off
	_tank_sound_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	_tank_sound_player.panning_strength = 1.0
	_tank_sound_player.autoplay = false
	
	# Add to tank node so it follows the tank and gets proper 3D positioning
	tank.add_child(_tank_sound_player)
	
	# Initialize tracking for doppler
	_tank_last_position = tank.global_position


func _update_tank_audio(_delta: float) -> void:
	"""Update tank driving sound based on speed - pitch/volume scale with speed."""
	if not _tank_sound_player or not tank_movement:
		return
	
	var is_tank_moving = tank_movement.is_moving() and not tank_movement.is_stopped()
	var current_speed_ms = tank_movement.get_current_speed()  # m/s
	var current_speed_kmh = current_speed_ms * 3.6  # Convert to km/h
	
	if is_tank_moving and current_speed_kmh > 0.1:
		# Calculate pitch and volume scale based on speed ratio to base (25 km/h)
		var speed_ratio = current_speed_kmh / TANK_BASE_SPEED_KMH
		
		# Pitch scales linearly with speed (faster = higher pitch)
		# At 25 km/h: pitch = 1.0, at 50 km/h: pitch = 2.0, at 12.5 km/h: pitch = 0.5
		var target_pitch = clampf(speed_ratio, 0.5, 2.0)
		
		# Volume scales with speed (louder when faster)
		# Use logarithmic scaling for more natural sound
		# At 25 km/h: 0 dB, at 50 km/h: +3 dB, at 12.5 km/h: -3 dB
		var volume_ratio = log(speed_ratio + 0.1) / log(2.0)  # log base 2
		var target_volume_db = clampf(volume_ratio * 6.0, -12.0, 6.0)
		
		_tank_sound_player.pitch_scale = target_pitch
		_tank_sound_player.volume_db = target_volume_db
		
		# Start playing if not already
		if not _tank_sound_player.playing:
			_tank_sound_player.play()
	else:
		# Tank not moving - stop sound
		if _tank_sound_player.playing:
			_tank_sound_player.stop()
	
	# Update position tracking for doppler (handled automatically by AudioStreamPlayer3D
	# when attached to moving node, but we track for debug purposes)
	var tank = event_watcher.get_tank() if event_watcher else null
	_tank_last_position = tank.global_position if tank else Vector3.ZERO


func _stop_simulation_audio() -> void:
	"""Stop propulsor, beep, and tank sounds (called on explosion)."""
	if _propulsor_player:
		_propulsor_player.stop()
	if _tank_sound_player:
		_tank_sound_player.stop()
	# Beep can continue or stop - let's stop it
	_audio_initialized = false


func _play_explosion_sound() -> void:
	"""Play explosion sound effect."""
	if _explosion_player:
		_explosion_player.play()


func _play_end_scenario_audio(success: bool) -> void:
	"""Play appropriate audio for scenario end.
	Note: Explosion sound is already played at moment of impact."""
	
	if success:
		# Success: just play main menu music after short delay
		await get_tree().create_timer(1.5).timeout
		if _music_player:
			_music_player.play()
	else:
		# Fail: play fail SFX, then main menu music
		if _fail_sfx_player:
			_fail_sfx_player.play()
			await _fail_sfx_player.finished
		# Then play music
		if _music_player:
			_music_player.play()


func _cleanup_audio() -> void:
	"""Clean up all audio players."""
	if _propulsor_player:
		_propulsor_player.stop()
		_propulsor_player.queue_free()
		_propulsor_player = null
	if _beep_player:
		_beep_player.stop()
		_beep_player.queue_free()
		_beep_player = null
	if _explosion_player:
		_explosion_player.stop()
		_explosion_player.queue_free()
		_explosion_player = null
	if _fail_sfx_player:
		_fail_sfx_player.stop()
		_fail_sfx_player.queue_free()
		_fail_sfx_player = null
	if _music_player:
		_music_player.stop()
		_music_player.queue_free()
		_music_player = null
	if _tank_sound_player:
		_tank_sound_player.stop()
		_tank_sound_player.queue_free()
		_tank_sound_player = null
	if _camera_switch_player:
		_camera_switch_player.stop()
		_camera_switch_player.queue_free()
		_camera_switch_player = null
	_audio_initialized = false

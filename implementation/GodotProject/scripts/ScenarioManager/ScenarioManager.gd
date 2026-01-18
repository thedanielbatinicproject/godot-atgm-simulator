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
	event_watcher.projectile_out_of_bounds.connect(_on_projectile_out_of_bounds)
	event_watcher.cutscene_distance_reached.connect(_on_cutscene_distance_reached)
	event_watcher.scenario_timeout.connect(_on_scenario_timeout)
	event_watcher.player_control_delay_finished.connect(_on_player_control_delay_finished)
	
	# Cutscene signals
	cutscene_manager.cutscene_finished.connect(_on_cutscene_finished)
	cutscene_manager.hit_animation_finished.connect(_on_hit_animation_finished)
	cutscene_manager.miss_animation_finished.connect(_on_miss_animation_finished)
	cutscene_manager.tank_should_stop.connect(_on_tank_should_stop)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_toggle"):
		if state.is_state(ScenarioStateClass.State.RUNNING):
			pause_scenario()
		elif state.is_state(ScenarioStateClass.State.PAUSED):
			resume_scenario()
	
	# Camera switching
	if event.is_action_pressed("switch_camera"):
		if state.is_state(ScenarioStateClass.State.RUNNING) or state.is_state(ScenarioStateClass.State.CUTSCENE):
			camera_manager.switch_camera()


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
	
	if state.is_state(ScenarioStateClass.State.CUTSCENE):
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
	get_tree().paused = true
	_show_pause_menu()
	scenario_paused.emit()


func resume_scenario() -> void:
	if not state.can_transition_to(ScenarioStateClass.State.RUNNING):
		return
	
	_hide_pause_menu()
	get_tree().paused = false
	state.transition_to(ScenarioStateClass.State.RUNNING)
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
	
	# Get physics space state
	var space_state: PhysicsDirectSpaceState3D = null
	if tank is Node3D:
		space_state = tank.get_world_3d().direct_space_state
	
	if not space_state:
		push_error("[ScenarioManager] Could not get physics space state for tank movement")
		return
	
	# Create tank movement controller
	tank_movement = TankMovementControllerClass.new()
	tank_movement.name = "TankMovementController"
	add_child(tank_movement)
	
	# Setup the controller
	tank_movement.setup(tank, space_state)
	
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
		narrator.play_default_message("You have control!", 2.0)


func _set_hud_visible(visible: bool) -> void:
	"""Show or hide the HUD based on player control state."""
	if _hud_instance:
		_hud_instance.visible = visible


func _on_cutscene_distance_reached() -> void:
	if not state.can_transition_to(ScenarioStateClass.State.CUTSCENE):
		return
	
	# Disable player control and hide HUD
	player_control_changed.emit(false)
	_set_hud_visible(false)
	
	# Start cutscene
	state.transition_to(ScenarioStateClass.State.CUTSCENE)
	
	var projectile = event_watcher.get_projectile()
	var tank = event_watcher.get_tank()
	
	# Disable user input during cutscene - physics simulation continues!
	# The projectile will keep flying until it hits the tank (collision detected)
	if projectile and projectile.has_method("disable_user_input"):
		projectile.disable_user_input()
	
	cutscene_manager.start_final_cutscene(projectile, tank)


func _on_projectile_hit_tank() -> void:
	"""Called when projectile collides with tank - SUCCESS!"""
	print("[ScenarioManager] Projectile hit tank!")
	
	# Get projectile position for explosion
	var projectile = event_watcher.get_projectile()
	var hit_pos = projectile.global_position if projectile else Vector3.ZERO
	
	# Play hit animation (handles explosion and projectile hiding)
	cutscene_manager.play_hit_animation(hit_pos)
	
	# Narrator message
	narrator.play_default_message("TARGET DESTROYED!", 3.0)


func _on_projectile_hit_ground(position: Vector3) -> void:
	"""Called when projectile hits ground (misses tank) - FAILURE!"""
	print("[ScenarioManager] Projectile hit ground at: ", position)
	
	# If we're still in RUNNING state, transition to cutscene first
	if state.is_state(ScenarioStateClass.State.RUNNING):
		state.transition_to(ScenarioStateClass.State.CUTSCENE)
		player_control_changed.emit(false)
		_set_hud_visible(false)
		
		# Disable user input
		var projectile = event_watcher.get_projectile()
		if projectile and projectile.has_method("disable_user_input"):
			projectile.disable_user_input()
		
		# Start cutscene camera (will track explosion)
		var tank = event_watcher.get_tank()
		cutscene_manager.start_final_cutscene(projectile, tank)
	
	# Play miss animation (handles explosion and projectile hiding)
	cutscene_manager.play_miss_animation(position)
	
	# Narrator message
	narrator.play_default_message("MISSED! Target survived.", 3.0)


func _on_tank_should_stop() -> void:
	"""Called when tank should stop (hit by projectile)."""
	if tank_movement:
		tank_movement.stop()
		print("[ScenarioManager] Tank stopped")


func _on_projectile_out_of_bounds() -> void:
	_end_scenario(false, "OUT OF BOUNDS")


func _on_scenario_timeout() -> void:
	_end_scenario(false, "TIME'S UP")


func _on_cutscene_finished() -> void:
	pass  # Cutscene cleanup handled elsewhere


func _on_hit_animation_finished() -> void:
	# Show success screen while keeping camera active
	_show_end_screen_overlay(true, "MISSION COMPLETE")


func _on_miss_animation_finished() -> void:
	# Show failure screen while keeping camera active
	_show_end_screen_overlay(false, "MISSION FAILED")


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
	# Connect signals if available
	if _pause_menu_instance.has_signal("resume_pressed"):
		_pause_menu_instance.connect("resume_pressed", resume_scenario)
	if _pause_menu_instance.has_signal("exit_pressed"):
		_pause_menu_instance.connect("exit_pressed", exit_scenario)
	
	# Preload and add Mission Success Screen (hidden)
	_success_screen_instance = MISSION_SUCCESS_SCENE.instantiate()
	_success_screen_instance.visible = false
	_hud_layer.add_child(_success_screen_instance)
	# Connect exit signal if available
	if _success_screen_instance.has_signal("exit_pressed"):
		_success_screen_instance.connect("exit_pressed", exit_scenario)
	if _success_screen_instance.has_signal("retry_pressed"):
		_success_screen_instance.connect("retry_pressed", _retry_scenario)
	
	# Preload and add Mission Failure Screen (hidden)
	_failure_screen_instance = MISSION_FAILURE_SCENE.instantiate()
	_failure_screen_instance.visible = false
	_hud_layer.add_child(_failure_screen_instance)
	# Connect exit signal if available
	if _failure_screen_instance.has_signal("exit_pressed"):
		_failure_screen_instance.connect("exit_pressed", exit_scenario)
	if _failure_screen_instance.has_signal("retry_pressed"):
		_failure_screen_instance.connect("retry_pressed", _retry_scenario)


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


func _show_end_screen(success: bool, _message: String) -> void:
	# Hide pause menu if visible
	if _pause_menu_instance:
		_pause_menu_instance.visible = false
	
	# Show appropriate end screen
	if success:
		if _success_screen_instance:
			_success_screen_instance.visible = true
		if _failure_screen_instance:
			_failure_screen_instance.visible = false
	else:
		if _failure_screen_instance:
			_failure_screen_instance.visible = true
		if _success_screen_instance:
			_success_screen_instance.visible = false


func _cleanup_scenario() -> void:
	# Stop all sub-managers
	event_watcher.stop_watching()
	cutscene_manager.cleanup()
	narrator.cleanup()
	environment.cleanup()
	camera_manager.cleanup()
	
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

extends Node

class_name ScenarioLoader

# ============================================================================
# SCENARIO LOADER
# ============================================================================
# Handles loading/unloading of scenario scenes and manages loading screen.
# ============================================================================

signal loading_started
signal loading_progress(progress: float)
signal loading_completed(scenario_root: Node)
signal loading_failed(error: String)

@export var loading_screen_scene: PackedScene
@export var min_loading_time: float = 0.5  # Minimum time to show loading screen

var _loading_screen: Control = null
var _scenario_root: Node = null
var _is_loading: bool = false


func start_loading(scenario_data: ScenarioData) -> void:
	if _is_loading:
		push_warning("ScenarioLoader: Already loading a scenario")
		return
	
	_is_loading = true
	loading_started.emit()
	
	# Show loading screen
	_show_loading_screen()
	
	# Start async loading
	_load_scenario_async(scenario_data)


func _show_loading_screen() -> void:
	if loading_screen_scene:
		_loading_screen = loading_screen_scene.instantiate()
		get_tree().root.add_child(_loading_screen)
	else:
		# Create a simple fallback loading screen
		_loading_screen = _create_fallback_loading_screen()
		get_tree().root.add_child(_loading_screen)


func _create_fallback_loading_screen() -> Control:
	var screen = ColorRect.new()
	screen.color = Color(0.1, 0.1, 0.1, 1.0)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var label = Label.new()
	label.text = "Loading..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	screen.add_child(label)
	
	return screen


func _hide_loading_screen() -> void:
	if _loading_screen:
		_loading_screen.queue_free()
		_loading_screen = null


func _load_scenario_async(scenario_data: ScenarioData) -> void:
	var start_time = Time.get_ticks_msec()
	
	# Create empty scenario root
	_scenario_root = Node.new()
	_scenario_root.name = "ScenarioRoot"
	
	# Load level scene
	loading_progress.emit(0.1)
	var level_node = await _load_scene(scenario_data.level_scene, "Level")
	if level_node == null:
		_handle_loading_error("Failed to load level scene")
		return
	_scenario_root.add_child(level_node)
	
	loading_progress.emit(0.4)
	
	# Load tank scene
	var tank_node = await _load_scene(scenario_data.tank_scene, "Tank")
	if tank_node:
		_setup_tank(tank_node, scenario_data)
		_scenario_root.add_child(tank_node)
	
	loading_progress.emit(0.6)
	
	# Load projectile scene
	var projectile_node = await _load_scene(scenario_data.projectile_scene, "Projectile")
	if projectile_node == null:
		_handle_loading_error("Failed to load projectile scene")
		return
	_setup_projectile(projectile_node, scenario_data)
	_scenario_root.add_child(projectile_node)
	
	loading_progress.emit(0.9)
	
	# Store scenario data reference
	_scenario_root.set_meta("scenario_data", scenario_data)
	
	# Ensure minimum loading time for smooth UX
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	if elapsed < min_loading_time:
		await get_tree().create_timer(min_loading_time - elapsed).timeout
	
	loading_progress.emit(1.0)
	
	# Hide loading screen and emit completion
	_hide_loading_screen()
	_is_loading = false
	loading_completed.emit(_scenario_root)


func _load_scene(packed_scene: PackedScene, node_name: String) -> Node:
	if packed_scene == null:
		push_warning("ScenarioLoader: PackedScene for '%s' is null" % node_name)
		return null
	
	var instance = packed_scene.instantiate()
	if instance:
		instance.name = node_name
	return instance


func _setup_tank(tank_node: Node, scenario_data: ScenarioData) -> void:
	# Set initial tank position from first path point
	if scenario_data.tank_path_positions.size() > 0:
		var initial_pos = scenario_data.tank_path_positions[0]
		if tank_node is Node3D:
			tank_node.position = initial_pos
		
		# Set initial orientation if available
		if scenario_data.tank_path_orientations.size() > 0:
			var euler = scenario_data.tank_path_orientations[0]
			tank_node.rotation_degrees = euler
	
	# Store path data for tank movement controller
	tank_node.set_meta("tank_path_positions", scenario_data.tank_path_positions)
	tank_node.set_meta("tank_path_speeds", scenario_data.tank_path_speeds)
	tank_node.set_meta("tank_path_orientations", scenario_data.tank_path_orientations)
	tank_node.set_meta("tank_initial_delay", scenario_data.tank_initial_delay)


func _setup_projectile(projectile_node: Node, scenario_data: ScenarioData) -> void:
	# Call initialize() on the projectile if it has the method (Projectile.gd)
	if projectile_node.has_method("initialize"):
		projectile_node.initialize(scenario_data)
	else:
		# Fallback for projectile scenes without initialize() method
		if projectile_node is Node3D:
			# Set initial position (use local, node not yet in tree)
			projectile_node.position = scenario_data.initial_position
			
			# Set initial rotation from basis
			projectile_node.transform.basis = scenario_data.get_initial_basis()
		
		# Store rocket data and initial state as meta
		projectile_node.set_meta("rocket_data", scenario_data.rocket_data)
		projectile_node.set_meta("initial_speed", scenario_data.initial_speed)
		projectile_node.set_meta("initial_velocity", scenario_data.get_initial_velocity_global())


func _handle_loading_error(error: String) -> void:
	push_error("ScenarioLoader: " + error)
	_hide_loading_screen()
	_is_loading = false
	
	if _scenario_root:
		_scenario_root.queue_free()
		_scenario_root = null
	
	loading_failed.emit(error)


func unload_scenario() -> void:
	if _scenario_root:
		_scenario_root.queue_free()
		_scenario_root = null


func get_scenario_root() -> Node:
	return _scenario_root


func is_loading() -> bool:
	return _is_loading

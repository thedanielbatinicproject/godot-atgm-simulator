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

const LOADING_SCENE = preload("res://scenes/UI/LoadingScene.tscn")

var _loading_screen: Control = null
var _loader_slider: HSlider = null
var _loader_per_label: Label = null
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
	_loading_screen = LOADING_SCENE.instantiate()
	get_tree().root.add_child(_loading_screen)
	
	# Find the LoaderSlider component
	_loader_slider = _loading_screen.get_node_or_null("BoxContainer/HBoxContainer/BoxContainer3/MarginContainer/LoaderSlider")
	if _loader_slider:
		_loader_slider.min_value = 0.0
		_loader_slider.max_value = 100.0
		_loader_slider.value = 0.0
		_loader_slider.editable = false  # User can't drag it
	else:
		push_warning("ScenarioLoader: LoaderSlider not found in LoadingScene")
	
	# Find the LoaderPer label for percentage display
	_loader_per_label = _loading_screen.get_node_or_null("BoxContainer/HBoxContainer/BoxContainer3/MarginContainer/LoaderPer")
	if _loader_per_label:
		_loader_per_label.text = "0%"
	else:
		push_warning("ScenarioLoader: LoaderPer label not found in LoadingScene")


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
	_loader_slider = null
	_loader_per_label = null


func _update_loading_progress(progress: float) -> void:
	"""Update the loading slider and percentage label, emit progress signal."""
	loading_progress.emit(progress)
	var percent = int(progress * 100.0)
	if _loader_slider:
		_loader_slider.value = percent
	if _loader_per_label:
		_loader_per_label.text = "%d%%" % percent


func _load_scenario_async(scenario_data: ScenarioData) -> void:
	var start_time = Time.get_ticks_msec()
	
	# Create empty scenario root
	_scenario_root = Node.new()
	_scenario_root.name = "ScenarioRoot"
	
	# Load level scene
	_update_loading_progress(0.1)
	await get_tree().process_frame  # Allow UI to update
	var level_node = await _load_scene(scenario_data.level_scene, "Level")
	if level_node == null:
		_handle_loading_error("Failed to load level scene")
		return
	_scenario_root.add_child(level_node)
	
	_update_loading_progress(0.4)
	await get_tree().process_frame
	
	# Load tank scene
	var tank_node = await _load_scene(scenario_data.tank_scene, "Tank")
	if tank_node:
		_setup_tank(tank_node, scenario_data, level_node)
		_scenario_root.add_child(tank_node)
	
	_update_loading_progress(0.6)
	await get_tree().process_frame
	
	# Load projectile scene
	var projectile_node = await _load_scene(scenario_data.projectile_scene, "Projectile")
	if projectile_node == null:
		_handle_loading_error("Failed to load projectile scene")
		return
	_setup_projectile(projectile_node, scenario_data)
	_scenario_root.add_child(projectile_node)
	
	_update_loading_progress(0.9)
	await get_tree().process_frame
	
	# Store scenario data reference
	_scenario_root.set_meta("scenario_data", scenario_data)
	
	# Calculate intentional delay for better UX
	# Formula: 2s / loading_time for <1s, add 1s for >1s
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	var intentional_delay: float
	if elapsed < 1.0:
		intentional_delay = 2.0 / maxf(elapsed, 0.1)  # Prevent division by very small numbers
		intentional_delay = minf(intentional_delay, 3.0)  # Cap at 3 seconds extra
	else:
		intentional_delay = 1.0
	
	# Show loading at 100% during intentional delay
	_update_loading_progress(1.0)
	await get_tree().create_timer(intentional_delay).timeout
	
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


func _setup_tank(tank_node: Node, scenario_data: ScenarioData, _level_node: Node) -> void:
	"""Setup tank position and orientation based on path and terrain.
	Note: Terrain raycasting is deferred until tank is in scene tree.
	Path positions are Vector2 (x, z) - Y is calculated from terrain."""
	if not tank_node is Node3D:
		return
	
	var tank_3d = tank_node as Node3D
	var positions_2d = scenario_data.tank_path_positions  # PackedVector2Array
	
	if positions_2d.size() == 0:
		push_warning("ScenarioLoader: No tank path positions defined")
		return
	
	# Get initial position - only X,Z from path (Y will be set by terrain alignment)
	var initial_pos_2d = positions_2d[0]
	tank_3d.position = Vector3(initial_pos_2d.x, 0.0, initial_pos_2d.y)  # Y=0 temporary
	
	# Calculate Y rotation (yaw) - face towards next path point
	if positions_2d.size() > 1:
		var next_pos_2d = positions_2d[1]
		var direction_2d = next_pos_2d - initial_pos_2d
		if direction_2d.length() > 0.01:
			direction_2d = direction_2d.normalized()
			# Calculate yaw angle (rotation around Y axis)
			# In Godot: atan2(x, z) gives yaw angle
			var yaw = atan2(direction_2d.x, direction_2d.y)  # y component is Z axis
			tank_3d.rotation.y = yaw
	
	# Store path data for tank movement controller
	# Terrain alignment will be done by ScenarioManager after scene is in tree
	tank_3d.set_meta("tank_path_positions_2d", positions_2d)  # Store as Vector2 array
	tank_3d.set_meta("tank_path_speeds", scenario_data.tank_path_speeds)
	tank_3d.set_meta("tank_initial_delay", scenario_data.tank_initial_delay)
	tank_3d.set_meta("needs_terrain_alignment", true)  # Flag for deferred alignment


func raycast_terrain(world_pos: Vector3, space_state: PhysicsDirectSpaceState3D) -> Dictionary:
	"""Raycast downward to find terrain at given position.
	Called externally after scene is in tree."""
	var result = {"hit": false, "position": world_pos, "normal": Vector3.UP}
	
	if not space_state:
		return result
	
	# Cast ray from high above downward (use absolute positions)
	var ray_origin = Vector3(world_pos.x, 1000.0, world_pos.z)
	var ray_end = Vector3(world_pos.x, -1000.0, world_pos.z)
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1  # Layer 1 where terrain collision is
	
	var hit = space_state.intersect_ray(query)
	if hit:
		result.hit = true
		result.position = hit.position
		result.normal = hit.normal
	
	return result


func align_to_terrain_normal(node: Node3D, terrain_normal: Vector3) -> void:
	"""Align node's up vector to terrain normal while preserving forward direction.
	Public method - called by ScenarioManager after scene is in tree."""
	# Current forward direction (Z axis in local space)
	var forward = -node.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	
	# Calculate right vector from forward and terrain normal
	var right = forward.cross(terrain_normal).normalized()
	
	# Recalculate forward to be perpendicular to both
	forward = terrain_normal.cross(right).normalized()
	
	# Build new basis
	node.global_transform.basis = Basis(right, terrain_normal, -forward)


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

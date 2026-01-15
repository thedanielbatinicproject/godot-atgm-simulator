extends Node

class_name ScenarioEnvironment

# ============================================================================
# SCENARIO ENVIRONMENT
# ============================================================================
# Configures environment settings: fog, time of day, ambient lighting, wind.
# ============================================================================

var _world_environment: WorldEnvironment = null
var _directional_light: DirectionalLight3D = null
var _scenario_data: ScenarioData = null


func setup_environment(scenario_root: Node, scenario_data: ScenarioData) -> void:
	_scenario_data = scenario_data
	
	# Find or create WorldEnvironment
	_world_environment = _find_or_create_world_environment(scenario_root)
	
	# Find DirectionalLight3D (sun)
	_directional_light = _find_directional_light(scenario_root)
	
	# Apply settings
	_apply_fog_settings()
	_apply_time_of_day()
	_apply_ambient_lighting()
	_setup_wind()


func _find_or_create_world_environment(root: Node) -> WorldEnvironment:
	# Search for existing WorldEnvironment
	var we = _find_node_of_type(root, "WorldEnvironment")
	if we:
		return we
	
	# Create new one if not found
	var new_we = WorldEnvironment.new()
	new_we.name = "WorldEnvironment"
	new_we.environment = Environment.new()
	root.add_child(new_we)
	return new_we


func _find_directional_light(root: Node) -> DirectionalLight3D:
	return _find_node_of_type(root, "DirectionalLight3D")


func _find_node_of_type(root: Node, type_name: String) -> Node:
	if root.get_class() == type_name:
		return root
	
	for child in root.get_children():
		var found = _find_node_of_type(child, type_name)
		if found:
			return found
	
	return null


func _apply_fog_settings() -> void:
	if not _world_environment or not _world_environment.environment:
		return
	
	var env = _world_environment.environment
	
	if _scenario_data.fog_density > 0.0:
		env.fog_enabled = true
		env.fog_light_color = _scenario_data.fog_color
		env.fog_density = _scenario_data.fog_density * 0.01  # Scale to Godot's expected range
		env.fog_aerial_perspective = _scenario_data.fog_density * 0.5
	else:
		env.fog_enabled = false


func _apply_time_of_day() -> void:
	if not _directional_light:
		return
	
	var time = _scenario_data.time_of_day
	
	# Calculate sun angle based on time of day
	# 0 = midnight (sun below horizon), 12 = noon (sun at zenith)
	var sun_angle = (time - 6.0) * 15.0  # 15 degrees per hour, offset by 6am
	sun_angle = clamp(sun_angle, -90.0, 90.0)
	
	_directional_light.rotation_degrees.x = -sun_angle
	
	# Adjust light energy based on time
	var energy = 1.0
	if time < 6.0 or time > 20.0:
		# Night time
		energy = 0.1
	elif time < 8.0:
		# Early morning
		energy = lerp(0.3, 1.0, (time - 6.0) / 2.0)
	elif time > 18.0:
		# Evening
		energy = lerp(1.0, 0.3, (time - 18.0) / 2.0)
	
	_directional_light.light_energy = energy
	
	# Adjust light color based on time
	if time < 7.0 or time > 18.0:
		# Warm sunrise/sunset color
		_directional_light.light_color = Color(1.0, 0.8, 0.6)
	else:
		# Daylight color
		_directional_light.light_color = Color(1.0, 0.98, 0.95)


func _apply_ambient_lighting() -> void:
	if not _world_environment or not _world_environment.environment:
		return
	
	var env = _world_environment.environment
	env.ambient_light_energy = _scenario_data.ambient_light_energy


func _setup_wind() -> void:
	# Initialize wind function based on scenario data
	_scenario_data.setup_wind_for_scenario()


func get_wind_at_position(position: Vector3) -> Vector3:
	if _scenario_data:
		return _scenario_data.get_wind_at_position(position)
	return Vector3.ZERO


func cleanup() -> void:
	_world_environment = null
	_directional_light = null
	_scenario_data = null

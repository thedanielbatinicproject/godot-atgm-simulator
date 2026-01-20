extends Node

class_name ScenarioEnvironment

# ============================================================================
# SCENARIO ENVIRONMENT
# ============================================================================
# Configures environment settings: fog, time of day, ambient lighting, wind.
# Sets up skyboxes based on time of day, creates sun/moon light.
#
# Skybox assets:
# - ClearDay/DayClear12h.tres (9h-15h) - clear noon sky
# - CloudSkyDay/DayCloudy12h.tres (9h-15h, when foggy) - overcast sky
# - SunriseSky/SunriseClear8h.tres (5h-9h) - morning sky
# - SunsetSky/SunsetSky18h.tres (17h-21h) - evening sky
# - HighMoon/NightMoon24h.tres (21h-5h) - night sky with moon
# ============================================================================

# Skybox paths
const SKYBOX_CLEAR_DAY = "res://assets/Skyboxes/ClearDay/DayClear12h.tres"
const SKYBOX_CLOUDY_DAY = "res://assets/Skyboxes/CloudSkyDay/DayCloudy12h.tres"
const SKYBOX_SUNRISE = "res://assets/Skyboxes/SunriseSky/SunriseClear8h.tres"
const SKYBOX_SUNSET = "res://assets/Skyboxes/SunsetSky/SunsetSky18h.tres"
const SKYBOX_NIGHT = "res://assets/Skyboxes/HighMoon/NightMoon24h.tres"

var _world_environment: WorldEnvironment = null
var _directional_light: DirectionalLight3D = null
var _created_light: DirectionalLight3D = null  # Track if we created the light
var _scenario_data: ScenarioData = null


func setup_environment(scenario_root: Node, scenario_data: ScenarioData) -> void:
	_scenario_data = scenario_data
	
	print("[ScenarioEnvironment] Setting up environment for time: %.1fh" % scenario_data.time_of_day)
	
	# Find or create WorldEnvironment
	_world_environment = _find_or_create_world_environment(scenario_root)
	
	# Setup sky with appropriate skybox
	_setup_sky()
	
	# Find or create DirectionalLight3D (sun/moon)
	_directional_light = _find_directional_light(scenario_root)
	if not _directional_light:
		_create_celestial_light(scenario_root)
	
	# Apply settings
	_apply_time_of_day()
	_apply_fog_settings()
	_apply_ambient_lighting()
	_setup_wind()
	
	print("[ScenarioEnvironment] Environment setup complete")


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


func _setup_sky() -> void:
	"""Setup sky with appropriate skybox based on time of day."""
	if not _world_environment or not _world_environment.environment:
		return
	
	var env = _world_environment.environment
	var time = _scenario_data.time_of_day
	
	# Select skybox based on time
	var skybox_path = _get_skybox_for_time(time)
	
	# Load skybox material
	var sky_material = load(skybox_path) as PanoramaSkyMaterial
	if sky_material:
		env.background_mode = Environment.BG_SKY
		if not env.sky:
			env.sky = Sky.new()
		env.sky.sky_material = sky_material
		print("[ScenarioEnvironment] Loaded skybox: %s" % skybox_path)
	else:
		push_warning("[ScenarioEnvironment] Failed to load skybox: %s" % skybox_path)
		# Keep existing sky or use default
	
	# Setup glow for sun/fire effects
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_strength = 0.8
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# Tonemap settings
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = _get_exposure_for_time(time)


func _get_skybox_for_time(time: float) -> String:
	"""Select appropriate skybox based on time of day."""
	# Night: 21h - 5h
	if time >= 21.0 or time < 5.0:
		return SKYBOX_NIGHT
	
	# Sunrise: 5h - 9h
	if time >= 5.0 and time < 9.0:
		return SKYBOX_SUNRISE
	
	# Day: 9h - 15h
	if time >= 9.0 and time < 15.0:
		# Use cloudy sky if high fog density
		if _scenario_data.fog_density > 0.3:
			return SKYBOX_CLOUDY_DAY
		return SKYBOX_CLEAR_DAY
	
	# Afternoon: 15h - 17h (still clear day)
	if time >= 15.0 and time < 17.0:
		return SKYBOX_CLEAR_DAY
	
	# Sunset: 17h - 21h
	if time >= 17.0 and time < 21.0:
		return SKYBOX_SUNSET
	
	return SKYBOX_CLEAR_DAY  # Fallback


func _get_exposure_for_time(time: float) -> float:
	"""Get camera exposure adjustment for time of day."""
	# Night - slightly brighter exposure to see
	if time < 5.0 or time >= 21.0:
		return 1.3
	# Twilight
	if time < 7.0 or time >= 19.0:
		return 1.1
	# Day
	return 1.0


func _create_celestial_light(parent: Node) -> void:
	"""Create sun or moon directional light based on time of day."""
	var time = _scenario_data.time_of_day
	var is_night = time < 5.0 or time >= 21.0
	
	_created_light = DirectionalLight3D.new()
	_directional_light = _created_light
	
	if is_night:
		_created_light.name = "MoonLight"
		_created_light.light_color = Color(0.6, 0.65, 0.8)  # Blueish moonlight
		_created_light.light_energy = 0.2
		_created_light.shadow_opacity = 0.3
	else:
		_created_light.name = "SunLight"
		_created_light.light_color = Color(1.0, 0.98, 0.95)
		_created_light.light_energy = 1.0
		_created_light.shadow_opacity = 0.7
	
	_created_light.shadow_enabled = true
	_created_light.shadow_blur = 1.0
	_created_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	
	parent.add_child(_created_light)
	print("[ScenarioEnvironment] Created %s" % _created_light.name)


func _apply_fog_settings() -> void:
	if not _world_environment or not _world_environment.environment:
		return
	
	var env = _world_environment.environment
	var fog_density = _scenario_data.fog_density
	
	if fog_density > 0.001:
		env.fog_enabled = true
		env.fog_light_color = _scenario_data.fog_color
		
		# Convert user-friendly 0-1 density to actual fog parameters
		# 0 = no fog, 0.5 = moderate visibility, 1.0 = very dense
		env.fog_density = fog_density * 0.015  # Scale to reasonable range
		env.fog_light_energy = 0.6 + (1.0 - fog_density) * 0.4
		env.fog_sky_affect = 0.2 + fog_density * 0.5
		env.fog_height = 150.0
		env.fog_height_density = fog_density * 0.3
		
		# Aerial perspective for distant objects
		env.fog_aerial_perspective = fog_density * 0.6
		
		print("[ScenarioEnvironment] Fog enabled: density=%.2f, color=%s" % [fog_density, _scenario_data.fog_color])
	else:
		env.fog_enabled = false


func _apply_time_of_day() -> void:
	if not _directional_light:
		return
	
	var time = _scenario_data.time_of_day
	var is_night = time < 5.0 or time >= 21.0
	var is_twilight = (time >= 5.0 and time < 7.0) or (time >= 19.0 and time < 21.0)
	
	# Calculate sun/moon angle based on time of day
	# At noon (12h), sun is highest (~70° from horizon)
	# At midnight (0h), moon is at ~30° from horizon
	var celestial_angle: float
	if is_night:
		# Moon path (simpler, lower in sky)
		var night_progress = 0.0
		if time >= 21.0:
			night_progress = (time - 21.0) / 8.0  # 21h to 5h (wrapping)
		else:
			night_progress = (time + 3.0) / 8.0  # 0h to 5h
		celestial_angle = -30.0 - sin(night_progress * PI) * 20.0  # Moon arc
	else:
		# Sun path
		var noon_offset = absf(time - 12.0)  # 0 at noon, up to 7 at 5am/7pm
		var sun_height = 1.0 - (noon_offset / 7.0)
		sun_height = clampf(sun_height, 0.0, 1.0)
		celestial_angle = -20.0 - sun_height * 55.0  # -20° at horizon to -75° at noon
	
	_directional_light.rotation_degrees.x = celestial_angle
	_directional_light.rotation_degrees.y = -30.0  # Slight yaw for interesting shadows
	
	# Adjust light energy based on time
	var energy = 1.0
	if is_night:
		energy = 0.15  # Moonlight
		_directional_light.light_color = Color(0.6, 0.65, 0.8)  # Blue moonlight
	elif is_twilight:
		if time < 12.0:
			# Morning twilight - warm
			energy = lerpf(0.3, 0.9, (time - 5.0) / 2.0)
			_directional_light.light_color = Color(1.0, 0.75, 0.5)  # Orange sunrise
		else:
			# Evening twilight - warm
			energy = lerpf(0.9, 0.3, (time - 19.0) / 2.0)
			_directional_light.light_color = Color(1.0, 0.6, 0.4)  # Red sunset
	else:
		# Full daylight
		var warmth = absf(time - 12.0) / 5.0  # More warm color near edges
		_directional_light.light_color = Color(1.0, 0.97 - warmth * 0.1, 0.92 - warmth * 0.15)
		energy = 1.0
	
	_directional_light.light_energy = energy
	print("[ScenarioEnvironment] Light angle: %.1f°, energy: %.2f" % [celestial_angle, energy])


func _apply_ambient_lighting() -> void:
	if not _world_environment or not _world_environment.environment:
		return
	
	var env = _world_environment.environment
	var time = _scenario_data.time_of_day
	var is_night = time < 5.0 or time >= 21.0
	
	# Set ambient source to sky for natural lighting
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	
	# Apply user-specified energy with time-based multiplier
	var time_multiplier = 1.0
	if is_night:
		time_multiplier = 0.2
		env.ambient_light_color = Color(0.5, 0.55, 0.7)  # Blue tint
	elif time < 7.0 or time >= 19.0:
		time_multiplier = 0.5
		env.ambient_light_color = Color(1.0, 0.85, 0.7)  # Warm tint
	else:
		env.ambient_light_color = Color(1.0, 1.0, 1.0)  # Neutral
	
	env.ambient_light_energy = _scenario_data.ambient_light_energy * time_multiplier
	print("[ScenarioEnvironment] Ambient energy: %.2f (base: %.2f, mult: %.2f)" % [
		env.ambient_light_energy, _scenario_data.ambient_light_energy, time_multiplier
	])


func _setup_wind() -> void:
	# Initialize wind function based on scenario data
	_scenario_data.setup_wind_for_scenario()


func get_wind_at_position(position: Vector3) -> Vector3:
	if _scenario_data:
		return _scenario_data.get_wind_at_position(position)
	return Vector3.ZERO


func cleanup() -> void:
	if _created_light and is_instance_valid(_created_light):
		_created_light.queue_free()
		_created_light = null
	_world_environment = null
	_directional_light = null
	_scenario_data = null

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
	
	print("[ScenarioEnvironment] ========== ENVIRONMENT SETUP ==========")
	print("[ScenarioEnvironment] Scenario root: ", scenario_root.name if scenario_root else "NULL")
	print("[ScenarioEnvironment] Time of day: %.1fh" % scenario_data.time_of_day)
	print("[ScenarioEnvironment] Fog density: %.2f" % scenario_data.fog_density)
	print("[ScenarioEnvironment] Ambient energy: %.2f" % scenario_data.ambient_light_energy)
	
	# Find or create WorldEnvironment
	_world_environment = _find_or_create_world_environment(scenario_root)
	print("[ScenarioEnvironment] WorldEnvironment: ", _world_environment.name if _world_environment else "NULL")
	print("[ScenarioEnvironment] Environment resource: ", _world_environment.environment if _world_environment else "NULL")
	
	# Setup sky with appropriate skybox
	_setup_sky()
	
	# Find or create DirectionalLight3D (sun/moon)
	_directional_light = _find_directional_light(scenario_root)
	print("[ScenarioEnvironment] Found existing light: ", _directional_light.name if _directional_light else "NONE")
	if not _directional_light:
		_create_celestial_light(scenario_root)
	
	# Apply settings
	_apply_time_of_day()
	_apply_fog_settings()
	_apply_ambient_lighting()
	_setup_wind()
	
	print("[ScenarioEnvironment] ========== SETUP COMPLETE ==========")
	
	# Print final state
	if _world_environment and _world_environment.environment:
		var env = _world_environment.environment
		print("[ScenarioEnvironment] FINAL STATE:")
		print("  - Background mode: ", env.background_mode)
		print("  - Sky: ", env.sky)
		print("  - Fog enabled: ", env.fog_enabled)
		print("  - Ambient source: ", env.ambient_light_source)


func _find_or_create_world_environment(root: Node) -> WorldEnvironment:
	# Search for existing WorldEnvironment
	var we = _find_node_of_type(root, "WorldEnvironment")
	if we:
		print("[ScenarioEnvironment] Found existing WorldEnvironment: ", we.name)
		# CRITICAL: Ensure it has an Environment resource
		if not we.environment:
			print("[ScenarioEnvironment] WorldEnvironment had no Environment! Creating one...")
			we.environment = Environment.new()
		return we
	
	# Create new one if not found
	print("[ScenarioEnvironment] Creating new WorldEnvironment")
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
	if not _world_environment:
		push_error("[ScenarioEnvironment] No WorldEnvironment for sky setup!")
		return
	
	if not _world_environment.environment:
		print("[ScenarioEnvironment] Creating new Environment resource")
		_world_environment.environment = Environment.new()
	
	var env = _world_environment.environment
	var time = _scenario_data.time_of_day
	
	# Select skybox based on time
	var skybox_path = _get_skybox_for_time(time)
	print("[ScenarioEnvironment] Loading skybox: %s for time %.1fh" % [skybox_path, time])
	
	# Check if file exists
	if not ResourceLoader.exists(skybox_path):
		push_error("[ScenarioEnvironment] Skybox file not found: %s" % skybox_path)
		return
	
	# Load skybox material
	var sky_material = load(skybox_path)
	print("[ScenarioEnvironment] Loaded resource type: ", sky_material.get_class() if sky_material else "NULL")
	
	if sky_material:
		# Set background mode to sky
		env.background_mode = Environment.BG_SKY
		
		# Create or reuse Sky resource
		if not env.sky:
			env.sky = Sky.new()
			print("[ScenarioEnvironment] Created new Sky resource")
		
		# Assign material
		env.sky.sky_material = sky_material
		print("[ScenarioEnvironment] SUCCESS - Skybox assigned: %s" % skybox_path)
	else:
		push_error("[ScenarioEnvironment] Failed to load skybox: %s" % skybox_path)
		return
	
	# Get gradient-based lighting values
	var daylight_factor = _get_daylight_factor(time)  # 0 = midnight, 1 = noon
	
	# GLOW: scales with daylight (no glow at deep night, subtle glow at twilight, full at day)
	var glow_factor = _smooth_step(daylight_factor, 0.2, 0.5)  # Ramps up between 20% and 50% daylight
	env.glow_enabled = glow_factor > 0.05
	env.glow_intensity = lerpf(0.0, 0.3, glow_factor)
	env.glow_strength = lerpf(0.2, 0.7, glow_factor)
	env.glow_bloom = lerpf(0.0, 0.12, glow_factor)
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# EXPOSURE: slightly lower at night to preserve darkness, but not too extreme
	# 0.65 at midnight, 1.0 at noon
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = lerpf(0.65, 1.0, daylight_factor)
	
	# BACKGROUND ENERGY: controls skybox brightness
	# 0.3 at midnight (stars visible but darker), 1.0 at noon
	env.background_energy_multiplier = lerpf(0.3, 1.0, daylight_factor)
	
	print("[ScenarioEnvironment] Daylight factor: %.2f, exposure: %.2f, bg_energy: %.2f, glow: %.2f" % [
		daylight_factor, env.tonemap_exposure, env.background_energy_multiplier, env.glow_intensity
	])


func _get_skybox_for_time(time: float) -> String:
	"""Select appropriate skybox based on time of day.
	Note: Skyboxes are discrete assets, so we use thresholds here,
	but all other lighting uses smooth gradients."""
	# Deep night: 21h - 5h
	if time >= 21.0 or time < 5.0:
		return SKYBOX_NIGHT
	
	# Dawn transition: 5h - 7h
	if time >= 5.0 and time < 7.0:
		return SKYBOX_SUNRISE
	
	# Morning: 7h - 9h (still sunrise colors)
	if time >= 7.0 and time < 9.0:
		return SKYBOX_SUNRISE
	
	# Day: 9h - 16h
	if time >= 9.0 and time < 16.0:
		# Use cloudy sky if high fog density
		if _scenario_data.fog_density > 0.3:
			return SKYBOX_CLOUDY_DAY
		return SKYBOX_CLEAR_DAY
	
	# Afternoon to sunset: 16h - 19h
	if time >= 16.0 and time < 19.0:
		return SKYBOX_SUNSET
	
	# Dusk transition: 19h - 21h
	if time >= 19.0 and time < 21.0:
		return SKYBOX_SUNSET
	
	return SKYBOX_CLEAR_DAY  # Fallback


func _get_daylight_factor(time: float) -> float:
	"""Returns a smooth 0-1 value representing daylight intensity.
	0.0 = deep midnight (darkest)
	1.0 = high noon (brightest)
	Uses smooth cosine curve for natural day/night cycle."""
	# Convert time to radians: 0h = PI (midnight), 12h = 0 (noon)
	# This creates a smooth cosine wave peaking at noon
	var radians = (time - 12.0) / 12.0 * PI
	
	# Cosine gives: -1 at midnight (time=0 or 24), +1 at noon (time=12)
	# We transform to 0-1 range: 0 at midnight, 1 at noon
	var raw_factor = (cos(radians) + 1.0) / 2.0
	
	# Apply power curve to make night darker and transitions sharper
	# This makes twilight shorter and night/day more pronounced
	return pow(raw_factor, 1.3)


func _smooth_step(value: float, edge0: float, edge1: float) -> float:
	"""Hermite interpolation for smooth transitions.
	Returns 0 if value <= edge0, 1 if value >= edge1,
	and smooth interpolation in between."""
	var t = clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


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
	var user_density = _scenario_data.fog_density
	
	if user_density > 0.001:
		env.fog_enabled = true
		env.fog_light_color = _scenario_data.fog_color
		
		# VOLUMETRIC FOG with distance-based density
		# User expects: 0 = no fog, 0.5 = moderate, 1.0 = very dense
		# Fog should start at ~100m distance and increase with distance
		
		# Use very low density - fog accumulates over distance
		# 0.01 user value = barely visible at 500m
		# 0.5 user value = visible haze starting at 200m
		# 1.0 user value = dense fog, ~100m visibility
		env.fog_mode = 0  # Exponential mode
		env.fog_density = user_density * 0.0008  # MUCH lower base density
		
		# Light energy affects how bright the fog appears
		env.fog_light_energy = 0.8 + (1.0 - user_density) * 0.2
		
		# Sky affect - how much fog blends with sky at horizon
		env.fog_sky_affect = 0.3 + user_density * 0.4
		
		# Height fog - denser near ground
		env.fog_height = 50.0  # Height where fog starts to thin
		env.fog_height_density = user_density * 0.1  # Subtle height falloff
		
		# Aerial perspective - objects fade with distance (key for realism)
		# This makes distant objects appear hazier
		env.fog_aerial_perspective = 0.3 + user_density * 0.5
		
		print("[ScenarioEnvironment] Volumetric fog: user_density=%.2f, actual=%.6f" % [user_density, env.fog_density])
	else:
		env.fog_enabled = false


func _apply_time_of_day() -> void:
	if not _directional_light:
		return
	
	var time = _scenario_data.time_of_day
	var daylight_factor = _get_daylight_factor(time)  # 0 = midnight, 1 = noon
	
	# Calculate sun/moon angle based on time of day using smooth curve
	# At noon (12h): sun at ~-70° (high in sky)
	# At midnight (0h): moon at ~-25° (lower)
	# Smooth sinusoidal path
	var time_radians = (time - 6.0) / 12.0 * PI  # 6am = 0, 12pm = PI/2, 6pm = PI
	var celestial_height = sin(time_radians)  # -1 to 1
	var celestial_angle = -20.0 - (celestial_height + 1.0) / 2.0 * 55.0  # -20° to -75°
	
	_directional_light.rotation_degrees.x = celestial_angle
	_directional_light.rotation_degrees.y = -30.0 + time * 2.5  # Rotates through day
	
	# LIGHT ENERGY: smooth gradient based on daylight factor
	# Minimum 0.08 at midnight (subtle moonlight), maximum 0.85 at noon
	var base_energy = lerpf(0.08, 0.85, daylight_factor)
	
	# LIGHT COLOR: gradient from blue (night) -> orange (twilight) -> white (day)
	# Use daylight_factor to blend between colors
	var light_color: Color
	if daylight_factor < 0.15:
		# Deep night: blue moonlight
		light_color = Color(0.5, 0.55, 0.75)
	elif daylight_factor < 0.35:
		# Twilight transition: blend from blue to orange
		var t = (daylight_factor - 0.15) / 0.2
		light_color = Color(0.5, 0.55, 0.75).lerp(Color(1.0, 0.65, 0.4), t)
	elif daylight_factor < 0.6:
		# Morning/evening: blend from orange to neutral
		var t = (daylight_factor - 0.35) / 0.25
		light_color = Color(1.0, 0.65, 0.4).lerp(Color(1.0, 0.95, 0.9), t)
	else:
		# Day: neutral white with slight warmth
		light_color = Color(1.0, 0.98, 0.95)
	
	_directional_light.light_energy = base_energy
	_directional_light.light_color = light_color
	
	# Shadow intensity: softer at night, sharper during day
	_directional_light.shadow_opacity = lerpf(0.2, 0.75, daylight_factor)
	
	print("[ScenarioEnvironment] Time %.1fh: daylight=%.2f, angle=%.1f°, energy=%.2f" % [
		time, daylight_factor, celestial_angle, base_energy
	])


func _apply_ambient_lighting() -> void:
	if not _world_environment or not _world_environment.environment:
		return
	
	var env = _world_environment.environment
	var time = _scenario_data.time_of_day
	var daylight_factor = _get_daylight_factor(time)
	
	# Set ambient source to sky for natural lighting
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	
	# User expects ambient_light_energy to work as:
	# 0 = dark (no ambient)
	# 1 = sunset/medium intensity
	# 2 = bright noon
	var user_ambient = _scenario_data.ambient_light_energy
	
	# Time-based multiplier using smooth gradient
	# 0.08 at midnight (darker nights), 1.0 at noon
	var time_multiplier = lerpf(0.08, 1.0, daylight_factor)
	
	# AMBIENT COLOR: smooth gradient from blue (night) to neutral (day)
	# At night: blue tint for moonlight atmosphere
	# At twilight: warm orange/pink tint
	# At day: neutral white
	if daylight_factor < 0.2:
		# Night: blue tint
		var night_intensity = 1.0 - (daylight_factor / 0.2)
		env.ambient_light_color = Color(1.0, 1.0, 1.0).lerp(Color(0.4, 0.45, 0.65), night_intensity)
	elif daylight_factor < 0.4:
		# Twilight: transition from blue to warm
		var t = (daylight_factor - 0.2) / 0.2
		env.ambient_light_color = Color(0.4, 0.45, 0.65).lerp(Color(1.0, 0.85, 0.7), t)
	elif daylight_factor < 0.6:
		# Morning/evening: warm to neutral
		var t = (daylight_factor - 0.4) / 0.2
		env.ambient_light_color = Color(1.0, 0.85, 0.7).lerp(Color(1.0, 1.0, 1.0), t)
	else:
		# Day: neutral
		env.ambient_light_color = Color(1.0, 1.0, 1.0)
	
	env.ambient_light_energy = user_ambient * time_multiplier
	print("[ScenarioEnvironment] Ambient: energy=%.3f (base: %.2f × time_mult: %.3f), daylight=%.2f" % [
		env.ambient_light_energy, user_ambient, time_multiplier, daylight_factor
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

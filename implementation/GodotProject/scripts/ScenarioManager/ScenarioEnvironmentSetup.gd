extends Node
class_name ScenarioEnvironmentSetup

# ============================================================================
# SCENARIO ENVIRONMENT SETUP
# ============================================================================
# Sets up environment lighting, sky, fog based on ScenarioData settings:
# - TimeOfDay: 0-24h determines sun/moon position, sky, ambient
# - FogColor, FogDensity: Volumetric/distance fog settings
# - AmbientLightEnergy: Overall ambient brightness
#
# Skybox assets available:
# - ClearDay/DayClear12h.tres (9h-15h)
# - CloudSkyDay/DayCloudy12h.tres (9h-15h, overcast)
# - SunriseSky/SunriseClear8h.tres (5h-9h)
# - SunsetSky/SunsetSky18h.tres (17h-21h)
# - HighMoon/NightMoon24h.tres (21h-5h)
# ============================================================================

# Skybox paths
const SKYBOX_CLEAR_DAY = "res://assets/Skyboxes/ClearDay/DayClear12h.tres"
const SKYBOX_CLOUDY_DAY = "res://assets/Skyboxes/CloudSkyDay/DayCloudy12h.tres"
const SKYBOX_SUNRISE = "res://assets/Skyboxes/SunriseSky/SunriseClear8h.tres"
const SKYBOX_SUNSET = "res://assets/Skyboxes/SunsetSky/SunsetSky18h.tres"
const SKYBOX_NIGHT = "res://assets/Skyboxes/HighMoon/NightMoon24h.tres"

# Created nodes (for cleanup)
var _world_environment: WorldEnvironment = null
var _sun_light: DirectionalLight3D = null

# Reference to scenario data
var _scenario_data: ScenarioData = null


func setup_environment(scenario_data: ScenarioData, parent: Node) -> void:
	"""Setup the entire environment based on scenario data."""
	_scenario_data = scenario_data
	
	var time = scenario_data.time_of_day
	var fog_color = scenario_data.fog_color
	var fog_density = scenario_data.fog_density
	var ambient_energy = scenario_data.ambient_light_energy
	
	print("[EnvironmentSetup] Setting up environment for time: %.1fh" % time)
	
	# Create WorldEnvironment with sky and fog
	_create_world_environment(parent, time, fog_color, fog_density, ambient_energy)
	
	# Create sun or moon light
	_create_celestial_light(parent, time)
	
	print("[EnvironmentSetup] Environment setup complete")


func _create_world_environment(parent: Node, time: float, fog_color: Color, fog_density: float, ambient_energy: float) -> void:
	"""Create and configure WorldEnvironment node."""
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "ScenarioWorldEnvironment"
	
	var env = Environment.new()
	
	# === SKY ===
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	
	# Load appropriate skybox based on time
	var skybox_path = _get_skybox_for_time(time)
	var sky_material = load(skybox_path) as PanoramaSkyMaterial
	if sky_material:
		env.sky.sky_material = sky_material
		print("[EnvironmentSetup] Loaded skybox: %s" % skybox_path)
	else:
		# Fallback to procedural sky
		var proc_sky = ProceduralSkyMaterial.new()
		_configure_procedural_sky(proc_sky, time)
		env.sky.sky_material = proc_sky
		print("[EnvironmentSetup] Using procedural sky (fallback)")
	
	# === AMBIENT LIGHT ===
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient_energy * _get_ambient_multiplier_for_time(time)
	env.ambient_light_sky_contribution = 1.0
	
	# Adjust ambient color based on time
	var ambient_color = _get_ambient_color_for_time(time)
	env.ambient_light_color = ambient_color
	
	# === FOG ===
	if fog_density > 0.001:
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_light_energy = 0.5 + (1.0 - fog_density) * 0.5
		
		# Convert user-friendly 0-1 density to actual fog density
		# fog_density 0 = no fog, 0.5 = moderate, 1.0 = very dense
		env.fog_density = fog_density * 0.02  # Scale to reasonable range
		env.fog_sky_affect = 0.3 + fog_density * 0.4
		env.fog_height = 100.0  # Height fog starts
		env.fog_height_density = fog_density * 0.5
		
		print("[EnvironmentSetup] Fog enabled: density=%.2f, color=%s" % [fog_density, fog_color])
	else:
		env.fog_enabled = false
	
	# === TONEMAP & EXPOSURE ===
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = _get_exposure_for_time(time)
	env.tonemap_white = 1.0
	
	# === GLOW (subtle for sun/fire) ===
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_strength = 0.8
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	_world_environment.environment = env
	parent.add_child(_world_environment)


func _create_celestial_light(parent: Node, time: float) -> void:
	"""Create sun or moon directional light based on time of day."""
	_sun_light = DirectionalLight3D.new()
	
	var is_night = time < 5.0 or time >= 21.0
	var is_twilight = (time >= 5.0 and time < 7.0) or (time >= 19.0 and time < 21.0)
	
	if is_night:
		_sun_light.name = "MoonLight"
		_sun_light.light_color = Color(0.6, 0.65, 0.8)  # Blueish moonlight
		_sun_light.light_energy = 0.15
		_sun_light.shadow_enabled = true
		_sun_light.shadow_opacity = 0.3
	elif is_twilight:
		_sun_light.name = "TwilightSun"
		if time < 12.0:
			# Morning twilight - warm orange
			_sun_light.light_color = Color(1.0, 0.7, 0.4)
		else:
			# Evening twilight - orange-red
			_sun_light.light_color = Color(1.0, 0.5, 0.3)
		_sun_light.light_energy = 0.6
		_sun_light.shadow_enabled = true
		_sun_light.shadow_opacity = 0.5
	else:
		_sun_light.name = "SunLight"
		# Daytime sun - warm white to yellow
		var warmth = absf(time - 12.0) / 6.0  # More yellow near morning/evening
		_sun_light.light_color = Color(1.0, 0.95 - warmth * 0.15, 0.9 - warmth * 0.2)
		_sun_light.light_energy = 1.0
		_sun_light.shadow_enabled = true
		_sun_light.shadow_opacity = 0.7
	
	# Calculate sun/moon position (rotation)
	# At noon (12h), sun is highest; at midnight (0h/24h), moon is highest
	var angle = _calculate_celestial_angle(time)
	_sun_light.rotation_degrees = Vector3(angle, -30.0, 0.0)  # Slight yaw for interesting shadows
	
	# Shadow quality
	_sun_light.shadow_blur = 1.0
	_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	
	parent.add_child(_sun_light)
	print("[EnvironmentSetup] Created %s at angle %.1f°" % [_sun_light.name, angle])


func _get_skybox_for_time(time: float) -> String:
	"""Select appropriate skybox based on time of day."""
	# Night: 21h - 5h
	if time >= 21.0 or time < 5.0:
		return SKYBOX_NIGHT
	
	# Sunrise: 5h - 9h
	if time >= 5.0 and time < 9.0:
		return SKYBOX_SUNRISE
	
	# Day clear: 9h - 15h (default)
	if time >= 9.0 and time < 15.0:
		# Could alternate between clear and cloudy based on fog density
		if _scenario_data and _scenario_data.fog_density > 0.3:
			return SKYBOX_CLOUDY_DAY
		return SKYBOX_CLEAR_DAY
	
	# Afternoon to sunset: 15h - 17h
	if time >= 15.0 and time < 17.0:
		return SKYBOX_CLEAR_DAY
	
	# Sunset: 17h - 21h
	if time >= 17.0 and time < 21.0:
		return SKYBOX_SUNSET
	
	return SKYBOX_CLEAR_DAY


func _configure_procedural_sky(sky_mat: ProceduralSkyMaterial, time: float) -> void:
	"""Configure procedural sky as fallback."""
	var is_night = time < 5.0 or time >= 21.0
	
	if is_night:
		sky_mat.sky_top_color = Color(0.05, 0.05, 0.15)
		sky_mat.sky_horizon_color = Color(0.1, 0.1, 0.2)
		sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
		sky_mat.ground_horizon_color = Color(0.1, 0.1, 0.15)
		sky_mat.sun_angle_max = 0.0
	else:
		# Daytime
		var sun_height = _calculate_sun_height_factor(time)
		sky_mat.sky_top_color = Color(0.3, 0.5, 0.9) * sun_height
		sky_mat.sky_horizon_color = Color(0.6, 0.7, 0.9)
		sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.2)
		sky_mat.ground_horizon_color = Color(0.5, 0.5, 0.5)
		sky_mat.sun_angle_max = 30.0


func _calculate_celestial_angle(time: float) -> float:
	"""Calculate pitch angle for sun/moon based on time.
	Noon = -60° (sun high), midnight = -20° (moon lower on horizon)."""
	# Normalize time to 0-24
	time = fmod(time, 24.0)
	
	# Sun path: highest at noon (12h), lowest at midnight (0h)
	# Angle range: -20° (low) to -80° (high)
	var noon_offset = absf(time - 12.0)  # 0 at noon, 12 at midnight
	var height_factor = 1.0 - (noon_offset / 12.0)  # 1 at noon, 0 at midnight
	
	# Clamp for sunrise/sunset times
	var angle = lerpf(-20.0, -70.0, height_factor)
	
	return angle


func _calculate_sun_height_factor(time: float) -> float:
	"""Return 0-1 factor for how high sun is (1 = noon)."""
	var noon_offset = absf(time - 12.0)
	return 1.0 - clampf(noon_offset / 12.0, 0.0, 1.0)


func _get_ambient_multiplier_for_time(time: float) -> float:
	"""Get ambient light multiplier based on time of day."""
	# Night
	if time < 5.0 or time >= 21.0:
		return 0.15
	# Twilight
	if time < 7.0 or time >= 19.0:
		return 0.4
	# Day
	return 1.0


func _get_ambient_color_for_time(time: float) -> Color:
	"""Get ambient light color tint for time of day."""
	# Night - blue tint
	if time < 5.0 or time >= 21.0:
		return Color(0.5, 0.55, 0.7)
	# Sunrise - warm orange
	if time >= 5.0 and time < 8.0:
		return Color(1.0, 0.85, 0.7)
	# Day - neutral
	if time >= 8.0 and time < 17.0:
		return Color(1.0, 1.0, 1.0)
	# Sunset - warm red-orange
	if time >= 17.0 and time < 21.0:
		return Color(1.0, 0.75, 0.6)
	
	return Color(1.0, 1.0, 1.0)


func _get_exposure_for_time(time: float) -> float:
	"""Get camera exposure adjustment for time of day."""
	# Night - brighter exposure to see
	if time < 5.0 or time >= 21.0:
		return 1.5
	# Twilight
	if time < 7.0 or time >= 19.0:
		return 1.2
	# Bright day
	return 1.0


func cleanup() -> void:
	"""Remove created environment nodes."""
	if _world_environment and is_instance_valid(_world_environment):
		_world_environment.queue_free()
		_world_environment = null
	
	if _sun_light and is_instance_valid(_sun_light):
		_sun_light.queue_free()
		_sun_light = null
	
	_scenario_data = null

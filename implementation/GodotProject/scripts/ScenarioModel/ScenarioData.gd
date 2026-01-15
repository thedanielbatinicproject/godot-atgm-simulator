extends Resource

class_name ScenarioData

# ============================================================================
# SCENARIO CONFIGURATION
# ============================================================================
# Defines initial conditions, environment, and wind for a simulation scenario.
# Coordinate system: Godot native (X=right, Y=up, Z=forward)
# ============================================================================

# Wind profile library
var wind_profile: = load("res://scripts/ScenarioModel/WindProfile.gd")

# ============================================================================
# EXPORTED PROPERTIES
# ============================================================================

@export_category("Scenario")

@export_group("Identification")
@export var scenario_thumbnail: Texture2D = ResourceLoader.load("res://assets/UI/MainMenu/Graphics/scenario_thumb_placeholder.png")
## Unique name for this scenario.
@export var scenario_name: String = "Default Scenario"
## Difficulty for this scenario.
@export var scenario_difficulty: String = "Easy"
## Description of what this scenario tests or demonstrates.
@export_multiline var scenario_description: String = ""

@export_group("3D Scene")
## The 3D level/environment scene to load for this scenario.
@export var level_scene: PackedScene

# ============================================================================
# TANK CONFIGURATION
# ============================================================================
@export_group("Tank")
## 3D model of the tank (should include collision mesh)
@export var tank_scene: PackedScene
## Name of the tank (for UI or logic)
@export var tank_name: String = "Default Tank"
## Initial delay before tank starts moving (seconds)
@export var tank_initial_delay: float = 0.0

# Tank path definition: parallel arrays for easy Inspector editing
## Positions along the tank path (in meters)
@export var tank_path_positions: PackedVector3Array = PackedVector3Array() ## At least 2 required
## Speeds after each tank path point (in km/h)
@export var tank_path_speeds: Array[float] = [] ## Speed in km/h for each segment (default 25.0)
## Orientations for each tank path point (Euler angles in degrees)
@export var tank_path_orientations: Array[Vector3] = [] ## Orientation (Euler angles in degrees) for each point

# Helper methods for tank path data
func get_tank_path_point(idx: int) -> Dictionary:
	# Returns a dictionary with position, speed, and orientation for the given index
	var pos = tank_path_positions[idx] if idx < tank_path_positions.size() else Vector3.ZERO
	var speed = tank_path_speeds[idx] if idx < tank_path_speeds.size() else 25.0
	var orientation = tank_path_orientations[idx] if idx < tank_path_orientations.size() else Vector3.ZERO
	return {
		"position": pos,
		"speed_kmph": speed,
		"orientation": orientation
	}

func get_tank_path_length() -> int:
	# Returns the number of defined tank path points (minimum of all arrays)
	return min(tank_path_positions.size(), tank_path_speeds.size(), tank_path_orientations.size())


# --- USER-SELECTED GAME PROFILE AND CONTROLS ---
var game_profile: GameProfileData
var control_config: ControlConfig

func _ready():
	load_user_settings()

func load_user_settings():
	# Default indices: Easy profile (1), Default controls (0)
	var profile_index = 1
	var controls_index = 0

	# Load profile index from config
	var profile_cfg = ConfigFile.new()
	if profile_cfg.load("user://settings/profile.cfg") == OK:
		profile_index = profile_cfg.get_value("profile", "selected", 1)

	# Load controls index from config
	var controls_cfg = ConfigFile.new()
	if controls_cfg.load("user://settings/controls.cfg") == OK:
		controls_index = controls_cfg.get_value("controls", "selected", 0)

	# Resource paths
	var profile_paths = [
		"res://assets/GameProfiles/VeryEasy.tres",
		"res://assets/GameProfiles/Easy.tres",
		"res://assets/GameProfiles/Medium.tres",
		"res://assets/GameProfiles/Hard.tres",
		"res://assets/GameProfiles/VeryHard.tres"
	]
	var controls_paths = [
		"res://assets/Controls/Default.tres",
		"res://assets/Controls/OnlyJoystick.tres",
		"res://assets/Controls/OnlyKeyboard.tres",
		"res://assets/Controls/RelaxedControls.tres"
	]

	# Load resources, fallback if missing
	if profile_index < profile_paths.size():
		game_profile = load(profile_paths[profile_index])
	else:
		game_profile = load(profile_paths[1]) # Easy

	if controls_index < controls_paths.size():
		control_config = load(controls_paths[controls_index])
	else:
		control_config = load(controls_paths[0]) # Default


# ============================================================================
# PROJECTILE CONFIGURATION
# ============================================================================
@export_group("Projectile")
## Projectile scene (should include mesh, collision, logic, etc.)
@export var projectile_scene: PackedScene
## Rocket parameters resource (for physics, guidance, etc.)
@export var rocket_data: RocketData
## Initial global position (meters)
@export var initial_position: Vector3 = Vector3.ZERO
## Initial speed in the direction of the projectile's nose (m/s)
@export_range(0.0, 1000.0, 1.0, "suffix:m/s") var initial_speed: float = 100.0
## Initial pitch angle (α). Positive = nose up.
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var initial_pitch_alpha: float = 0.0
## Initial yaw angle (β). Positive = nose right.
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var initial_yaw_beta: float = 0.0
## Initial roll angle (γ). Positive = clockwise from behind.
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var initial_roll_gamma: float = 0.0

@export_group("Environment")
## Air density in kg/m³. Sea level standard: 1.225
@export_range(0.1, 2.0, 0.001, "suffix:kg/m³") var air_density: float = 1.225
## Gravitational acceleration in m/s².
@export_range(0.0, 20.0, 0.01, "suffix:m/s²") var gravity: float = 9.81
## Dynamic viscosity of air in kg/(m·s).
@export var air_viscosity: float = 1.8e-5

# ============================================================================
# ENVIRONMENT VISUALS
# ============================================================================
@export_group("Environment Visuals")
## Time of day in hours (0.0 = midnight, 12.0 = noon, 18.0 = sunset)
@export_range(0.0, 24.0, 0.1, "suffix:h") var time_of_day: float = 12.0
## Fog color
@export var fog_color: Color = Color(0.7, 0.7, 0.8, 1.0)
## Fog density (0 = no fog, 1 = very dense)
@export_range(0.0, 1.0, 0.01) var fog_density: float = 0.0
## Ambient light energy (0 = dark, 1 = default, >1 = brighter)
@export_range(0.0, 2.0, 0.01) var ambient_light_energy: float = 1.0

@export_group("Wind Configuration")
## Type of wind field to generate.
@export_enum("constant", "altitude_gradient", "sinusoidal", "vortex", "full_gradient") var wind_type: String = "sinusoidal"
## Base wind vector for constant/gradient wind types (m/s).
@export var wind_base_vector: Vector3 = Vector3.ZERO
## Amplitude of wind oscillations for sinusoidal wind (m/s).
@export var wind_amplitudes: Vector3 = Vector3(5.0, 3.0, 2.0)
## Frequency of wind oscillations for sinusoidal wind (Hz).
@export var wind_frequencies: Vector3 = Vector3(0.05, 0.03, 0.04)
## Wind gradient vector for gradient-based wind types.
@export var wind_gradient: Vector3 = Vector3.ZERO

# ============================================================================
# VOICE LINES
# ============================================================================
@export_group("Voice Lines")
## Time (in seconds) when each voice line should play
@export var voice_line_times: Array[float] = []
## Subtitle text for each voice line
@export var voice_line_texts: Array[String] = []
## Audio resource for each voice line (can be null)
@export var voice_line_audios: Array[AudioStream] = []

# Helper method to fetch voice line data as dictionary
func get_voice_line(idx: int) -> Dictionary:
	var time = voice_line_times[idx] if idx < voice_line_times.size() else 0.0
	var text = voice_line_texts[idx] if idx < voice_line_texts.size() else ""
	var audio = voice_line_audios[idx] if idx < voice_line_audios.size() else null
	return {
		"time": time,
		"text": text,
		"audio": audio
	}

@export_group("Player controls")
## Time in seconds before player can control the projectile.
@export_range(0.0, 10.0, 0.1, "suffix:s") var player_control_delay: float = 0.0
## Distance from tank or ground where final cutscene starts playing (meters).
@export_range(0.0, 500.0, 1.0, "suffix:m") var final_cutscene_start_distance: float = 50.0
## Maximum time in seconds for the scenario before auto-ending.
@export_range(10.0,1600.0, 1.0, "suffix:s") var max_scenario_time: float = 400.0
## Distance from terrain where projectile is considered leaving mission area (meters).
@export_range(10.0,15000.0, 1.0, "suffix:m") var mission_area_limit: float = 2000.0

func get_voice_line_count() -> int:
	return min(voice_line_times.size(), voice_line_texts.size(), voice_line_audios.size())

# VJETAR KAO VEKTORSKO POLJE
var wind_function: Callable = func(_pos: Vector3) -> Vector3:
	return Vector3.ZERO

# INICIJALIZACIJA

func _init(p_name: String = "DefaultScenario", p_level: PackedScene = null, 
		   p_rocket: Resource = null, p_wind_func: Callable = Callable()):
	scenario_name = p_name
	level_scene = p_level
	rocket_data = p_rocket
	if p_wind_func.is_valid():
		wind_function = p_wind_func

# POMOĆNE METODE

func setup_wind_for_scenario():
	"""kreira wind_function na osnovu wind_type i parametara."""
	match wind_type:
		"constant":
			wind_function = wind_profile.constant_wind(wind_base_vector)
		"altitude_gradient":
			wind_function = wind_profile.linear_altitude_wind(wind_base_vector, wind_gradient.y)
		"sinusoidal":
			wind_function = wind_profile.sinusoidal_wind(wind_amplitudes, wind_frequencies)
		"vortex":
			var center = Vector3(0, 0, 0)
			var strength = wind_amplitudes.x
			wind_function = wind_profile.vortex_wind(center, strength)
		"full_gradient":
			wind_function = wind_profile.full_gradient_wind(wind_base_vector, wind_gradient)
		_:
			wind_function = wind_profile.constant_wind(Vector3.ZERO)

func get_initial_velocity_global() -> Vector3:
	"""Pretvara početnu brzinu iz lokalnog u globalni sustav."""
	var local_velocity = Vector3(0, 0, initial_speed)
	var basis = get_initial_basis()
	return basis * local_velocity

func get_initial_basis() -> Basis:
	"""Vraća početnu rotacijsku matricu (Basis) iz Euler kuteva.
	
	Godot konvencija (desno pravilo ruke):
	- Pozitivna rotacija oko X = nos DOLJE
	- Pozitivna rotacija oko Y = nos LIJEVO
	
	Naša konvencija (intuitivna):
	- Pozitivan pitch (α) = nos GORE
	- Pozitivan yaw (β) = nos DESNO
	
	Zato invertiramo alpha i beta.
	"""
	return Basis.from_euler(Vector3(-initial_pitch_alpha, -initial_yaw_beta, initial_roll_gamma), EULER_ORDER_YXZ)

func get_initial_state() -> Dictionary:
	"""Vraća rječnik sa svim početnim varijablama stanja."""
	return {
		"position": initial_position,
		"velocity": get_initial_velocity_global(),
		"basis": get_initial_basis(),
		"alpha": initial_pitch_alpha,
		"beta": initial_yaw_beta,
		"gamma": initial_roll_gamma
	}

func get_wind_at_position(position: Vector3) -> Vector3:
	"""evaluira vjetarsku funkciju na danoj poziciji."""
	return wind_function.call(position)

func get_info() -> String:
		"""Returns a formatted string with scenario data."""
		var projectile_scene_name = "NOT LOADED" if projectile_scene == null else projectile_scene.resource_path
		var rocket_name = "NOT LOADED" if rocket_data == null else rocket_data.get_class()
		var level_name = "NOT LOADED" if level_scene == null else level_scene.resource_path

		var pos_x = "%.3f" % initial_position.x
		var pos_y = "%.3f" % initial_position.y
		var pos_z = "%.3f" % initial_position.z

		var global_vel = get_initial_velocity_global()
		var vel_x = "%.3f" % global_vel.x
		var vel_y = "%.3f" % global_vel.y
		var vel_z = "%.3f" % global_vel.z

		var alpha_deg = "%.2f" % rad_to_deg(initial_pitch_alpha)
		var beta_deg = "%.2f" % rad_to_deg(initial_yaw_beta)
		var gamma_deg = "%.2f" % rad_to_deg(initial_roll_gamma)
		var dens_str = "%.4f" % air_density
		var grav_str = "%.2f" % gravity
		var visc_str = "%.6f" % air_viscosity

		var info = """Scenario - ScenarioData
===================================
Name:                        %s
Description:                 %s

Environment:
	Level (scene):             %s

Projectile:
	Scene:                     %s
	Data:                      %s

Initial state:
	Position:                  (%s, %s, %s) m
	Speed (local):             %.1f m/s (nose direction)
	Speed (global):            (%s, %s, %s) m/s
	Euler angles:
		pitch (α):               %s deg
		yaw (β):                 %s deg
		roll (γ):                %s deg

Environment parameters:
	Air density:               %s kg/m³
	Gravity:                   %s m/s²
	Air viscosity:             %s kg/(m·s)
	Wind field:                Custom function
===================================
""" % [
				scenario_name, scenario_description,
				level_name,
				projectile_scene_name,
				rocket_name,
				pos_x, pos_y, pos_z,
				initial_speed,
				vel_x, vel_y, vel_z,
				alpha_deg, beta_deg, gamma_deg,
				dens_str, grav_str, visc_str
		]

		return info

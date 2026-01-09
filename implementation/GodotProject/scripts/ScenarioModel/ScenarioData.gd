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
@export var scenario_thumbnail: Texture2D
## Unique name for this scenario.
@export var scenario_name: String = "Default Scenario"
## Description of what this scenario tests or demonstrates.
@export_multiline var scenario_description: String = ""

@export_group("Scene")
## The 3D level/environment scene to load for this scenario.
@export var level_scene: PackedScene

@export_group("Projectile")
## Reference to the RocketData resource defining projectile properties.
@export var rocket_data: RocketData

@export_group("Game Profile")
## Reference to the GameProfileData resource with gameplay settings.
@export var game_profile: GameProfileData

@export_group("Controls")
## Reference to the ControlConfig resource with input settings.
@export var control_config: ControlConfig

@export_group("Initial Position")
## Starting position in meters (Godot: X=right, Y=up, Z=forward).
@export var initial_position: Vector3 = Vector3.ZERO

@export_group("Initial Velocity")
## Početna brzina u smjeru nosa projektila (lokalna +Z os) u m/s.
@export_range(0.0, 1000.0, 1.0, "suffix:m/s") var initial_speed: float = 100.0

@export_group("Initial Orientation")
## Početni pitch kut (α). Pozitivno = nos gore.
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var initial_pitch_alpha: float = 0.0
## Početni yaw kut (β). Pozitivno = nos desno.
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var initial_yaw_beta: float = 0.0
## Početni roll kut (γ). Pozitivno = u smjeru kazaljke gledano od iza.
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var initial_roll_gamma: float = 0.0

@export_group("Environment")
## Air density in kg/m³. Sea level standard: 1.225
@export_range(0.1, 2.0, 0.001, "suffix:kg/m³") var air_density: float = 1.225
## Gravitational acceleration in m/s².
@export_range(0.0, 20.0, 0.01, "suffix:m/s²") var gravity: float = 9.81
## Dynamic viscosity of air in kg/(m·s).
@export var air_viscosity: float = 1.8e-5

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
	"""Vraća formatiran string s podacima scenarija."""
	var rocket_name = "NIJE UČITAN" if rocket_data == null else rocket_data.get_class()
	var level_name = "NIJE UČITAN" if level_scene == null else level_scene.resource_path
	
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
Naziv:                       %s
Opis:                        %s

Okruzenje:
  Level (scene):             %s
  
Projektil:
  Model:                     %s
  
Početno stanje:
  Pozicija:                  (%s, %s, %s) m
  Brzina (lokalna):          %.1f m/s (smjer nosa)
  Brzina (globalna):         (%s, %s, %s) m/s
  Eulerovi kutovi:
    pitch (α):               %s deg
    yaw (β):                 %s deg
    roll (γ):                %s deg
  
Okoljni parametri:
  Gustoća zraka:             %s kg/m³
  Gravitacija:               %s m/s²
  Viskoznost zraka:          %s kg/(m·s)
  Vjetarsko polje:           Prilagođena funkcija
===================================
""" % [
		scenario_name, scenario_description,
		level_name,
		rocket_name,
		pos_x, pos_y, pos_z,
		initial_speed,
		vel_x, vel_y, vel_z,
		alpha_deg, beta_deg, gamma_deg,
		dens_str, grav_str, visc_str
	]
	
	return info

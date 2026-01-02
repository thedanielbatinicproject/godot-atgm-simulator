extends Resource
class_name ScenarioData

# BIBLIOTEKA VJETRA
var wind_profile: = load("res://scripts/ScenarioModel/WindProfile.gd")

# SCENARIO IDENTIFIKACIJA
@export var scenario_name: String = "DefaultScenario"
@export var scenario_description: String = ""

# 3D OKRUZENJE
@export var level_scene: PackedScene

# KONFIGURACIJA PROJEKTILA
@export var rocket_data: RocketData

# POČETNE VARIJABLE STANJA (Godot koordinate - Y je gore, -Z je naprijed)
# Ovo se automatski konvertira u Model koordinate (X naprijed, Z gore) u Projectile.gd
@export var initial_position: Vector3 = Vector3.ZERO
@export var initial_velocity: Vector3 = Vector3(0, 0, -100)  # -Z = naprijed u Godotu = X u Modelu
@export var initial_alpha: float = 0.0
@export var initial_beta: float = 0.0
@export var initial_gamma: float = 0.0

# OKOLJNE KONSTANTE
@export var air_density: float = 1.225
@export var gravity: float = 9.81
@export var air_viscosity: float = 1.8e-5

# KONFIGURACIJA VJETRA
@export var wind_type: String = "sinusoidal"  # constant, altitude_gradient, sinusoidal, vortex, combined
@export var wind_base_vector: Vector3 = Vector3.ZERO
@export var wind_amplitudes: Vector3 = Vector3(5.0, 3.0, 2.0)
@export var wind_frequencies: Vector3 = Vector3(0.05, 0.03, 0.04)
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

func get_initial_state() -> Dictionary:
	"""vraća rječnik sa svim početnim varijablama stanja."""
	return {
		"position": initial_position,
		"velocity": initial_velocity,
		"alpha": initial_alpha,
		"beta": initial_beta,
		"gamma": initial_gamma
	}

func get_wind_at_position(position: Vector3) -> Vector3:
	"""evaluira vjetarsku funkciju na danoj poziciji."""
	return wind_function.call(position)

func get_info() -> String:
	"""vraća formatiran string s podacima scenarija."""
	var rocket_name = "NIJE UČITAN" if rocket_data == null else rocket_data.get_class()
	var level_name = "NIJE UČITAN" if level_scene == null else level_scene.resource_path
	
	var pos_x = "%.3f" % initial_position.x
	var pos_y = "%.3f" % initial_position.y
	var pos_z = "%.3f" % initial_position.z
	var vel_x = "%.3f" % initial_velocity.x
	var vel_y = "%.3f" % initial_velocity.y
	var vel_z = "%.3f" % initial_velocity.z
	var alpha_deg = "%.2f" % rad_to_deg(initial_alpha)
	var beta_deg = "%.2f" % rad_to_deg(initial_beta)
	var gamma_deg = "%.2f" % rad_to_deg(initial_gamma)
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
  Brzina:                    (%s, %s, %s) m/s
  Eulerovi kutovi:
    roll:                    %s deg
    pitch:                   %s deg
    yaw:                     %s deg
  
Okoljni parametri:
  Gustoća zraka:             %s kg/m^3
  Gravitacija:               %s m/s^2
  Viskoznost zraka:          %s kg/(m*s)
  Vjetarsko polje:           Prilagođena funkcija
===================================
""" % [
		scenario_name, scenario_description,
		level_name,
		rocket_name,
		pos_x, pos_y, pos_z,
		vel_x, vel_y, vel_z,
		alpha_deg, beta_deg, gamma_deg,
		dens_str, grav_str, visc_str
	]
	
	return info

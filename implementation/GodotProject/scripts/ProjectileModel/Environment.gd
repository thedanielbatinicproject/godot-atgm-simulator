extends Node
class_name ModelEnvironment

# VJETAR KAO VEKTORSKO POLJE
var wind_function: Callable = func(_pos: Vector3) -> Vector3:
	return Vector3.ZERO

# ZRAK
var air_density: float = 1.225
var air_viscosity: float = 1.8e-5

# GRAVITACIJA
var gravity: float = 9.81

# INICIJALIZACIJA

func _init(p_wind_func: Callable = Callable(), p_air_density: float = 1.225, 
		   p_gravity: float = 9.81):
	if p_wind_func.is_valid():
		wind_function = p_wind_func
	air_density = p_air_density
	gravity = p_gravity

# SETTERI

func set_wind_function(wind_func: Callable):
	"""postavlja wind funkciju."""
	wind_function = wind_func

func set_air_density(density: float):
	"""postavlja gustoću zraka (kg/m³)."""
	air_density = max(0.01, density)

func set_gravity(g: float):
	"""postavlja gravitacijsku akceleraciju (m/s²)."""
	gravity = max(0.01, g)

# GETTERI

func get_wind_at_position(position: Vector3) -> Vector3:
	"""evaluira wind funkciju na zadanoj poziciji."""
	return wind_function.call(position)

func get_air_density() -> float:
	return air_density

func get_gravity() -> float:
	return gravity

# RESET

func reset_to_defaults():
	"""resetira parametre na default vrijednosti."""
	wind_function = func(_pos: Vector3) -> Vector3:
		return Vector3.ZERO
	air_density = 1.225
	air_viscosity = 1.8e-5
	gravity = 9.81

# FIZIKALNIH SVOJSTAVA

func get_air_properties_at_altitude(_altitude: float) -> Dictionary:
	"""vraća svojstva zraka (trenutno konstante, može biti prošireno)."""
	return {
		"density": air_density,
		"viscosity": air_viscosity,
		"speed_of_sound": 340.0
	}

# DEBUG

func get_environment_info() -> String:
	var density_str = "%.4f" % air_density
	var viscosity_str = "%.6f" % air_viscosity
	var gravity_str = "%.2f" % gravity
	
	var info = """Okoline - ModelEnvironment
===================================
Vektorsko polje vjetra:  Prilagođena funkcija
Gustoća zraka:           %s kg/m^3
Viskoznost:              %s kg/(m*s)
Gravitacija:             %s m/s^2
===================================
""" % [density_str, viscosity_str, gravity_str]
	
	return info

extends Node
class_name Moments

# KONFIGURACIJA
var rocket_data: Resource

# INICIJALIZACIJA

func _init(p_rocket_data: Resource = null):
	rocket_data = p_rocket_data

# MOMENTI

func calculate_thrust_moment(_state: StateVariables, _thrust_force: Vector3) -> Vector3:
	"""moment od asimetrične potisne sile - implementacija u fazi 3."""
	return Vector3.ZERO

func calculate_stabilization_moment(_state: StateVariables, _wind_velocity: Vector3) -> Vector3:
	"""aerodinamički stabilizacijski moment - implementacija u fazi 3."""
	return Vector3.ZERO

# UKUPAN MOMENT

func calculate_total(state: StateVariables, thrust_force: Vector3, wind_velocity: Vector3 = Vector3.ZERO) -> Vector3:
	"""kombinira sve momente oko centra mase (lokalni sustav)."""
	var m_thrust = calculate_thrust_moment(state, thrust_force)
	var m_stab = calculate_stabilization_moment(state, wind_velocity)
	
	return m_thrust + m_stab

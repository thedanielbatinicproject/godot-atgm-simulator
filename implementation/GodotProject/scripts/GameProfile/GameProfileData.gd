extends Resource
class_name GameProfileData

# ============================================================================
# GAME PROFILE
# ============================================================================
# Contains user-configurable gameplay settings that affect simulation behavior.
# ============================================================================

@export_category("Game Profile")

@export_group("Profile Info")
## Name of this game profile (e.g., "Easy", "Realistic", "Arcade")
@export var profile_name: String = "Default"
## Description of what this profile offers
@export_multiline var description: String = "Default game profile with balanced settings."

@export_group("Idle Control")
## Percentage of thrust used for moment calculation when actual thrust is zero.
## This simulates minimal control authority even without propulsion.
## 0 = No control when idle (realistic)
## 5 = 5% thrust equivalent for rotation only (arcade)
## Only affects rotation/moments, NOT linear thrust forces.
@export_range(0.0, 50.0, 1.0, "suffix:%") var idle_moment_thrust_percentage: float = 0.0

## Returns the idle moment thrust as a decimal (0.0 to 0.5)
func get_idle_thrust_factor() -> float:
	return idle_moment_thrust_percentage / 100.0

@export_group("Control Latency")
## Delay before thrust changes take effect (seconds).
## Lower = more responsive, Higher = more realistic
@export_range(0.0, 1.0, 0.001, "suffix:s") var thrust_latency: float = 0.01
## Delay before gimbal changes take effect (seconds).
## Lower = more responsive, Higher = more realistic
@export_range(0.0, 1.0, 0.001, "suffix:s") var gimbal_latency: float = 0.02

@export_group("Aerodynamics")
## Koeficijent usklađivanja brzine s orijentacijom projektila.
## Veće vrijednosti = brzina se brže usklađuje sa smjerom nosa.
## 0 = nema usklađivanja, projektil klizi bočno
## 0.5 = umjereno usklađivanje (default)
## 2+ = agresivno usklađivanje
@export_range(0.0, 9.0, 0.1) var velocity_alignment_coefficient: float = 0.5

@export_group("Assistance")
## Enable automatic stabilization assistance
@export var auto_stabilization: bool = false
## Strength of automatic stabilization (if enabled)
@export_range(0.0, 1.0, 0.1) var stabilization_strength: float = 0.3

@export_group("Roll Control")
## Maksimalna kutna brzina rolla u rad/s.
@export_range(0.0, 10.0, 0.1, "suffix:rad/s") var roll_max_speed: float = 3.0
## Kutna akceleracija rolla u rad/s². Veća = brže ubrzavanje.
@export_range(0.0, 30.0, 0.5, "suffix:rad/s²") var roll_acceleration: float = 8.0
## Koeficijent prigušenja rolla. Veća = brže usporavanje kada nema inputa.
@export_range(0.0, 20.0, 0.5) var roll_damping: float = 3.0

# ============================================================================
# PRESET FACTORIES
# ============================================================================

static func create_realistic() -> GameProfileData:
	"""Create a realistic game profile with no assistance."""
	var profile = GameProfileData.new()
	profile.profile_name = "Realistic"
	profile.description = "Realistic simulation with no control assistance."
	profile.idle_moment_thrust_percentage = 0.0
	profile.thrust_latency = 0.05
	profile.gimbal_latency = 0.08
	profile.velocity_alignment_coefficient = 0.3
	profile.auto_stabilization = false
	profile.roll_max_speed = 2.0
	profile.roll_acceleration = 4.0
	profile.roll_damping = 1.5
	return profile

static func create_arcade() -> GameProfileData:
	"""Create an arcade game profile with maximum assistance."""
	var profile = GameProfileData.new()
	profile.profile_name = "Arcade"
	profile.description = "Arcade mode with control assistance for easier gameplay."
	profile.idle_moment_thrust_percentage = 10.0
	profile.thrust_latency = 0.005
	profile.gimbal_latency = 0.01
	profile.velocity_alignment_coefficient = 1.0
	profile.auto_stabilization = true
	profile.stabilization_strength = 0.5
	profile.roll_max_speed = 5.0
	profile.roll_acceleration = 15.0
	profile.roll_damping = 8.0
	return profile

static func create_balanced() -> GameProfileData:
	"""Create a balanced game profile."""
	var profile = GameProfileData.new()
	profile.profile_name = "Balanced"
	profile.description = "Balanced settings with minimal assistance."
	profile.idle_moment_thrust_percentage = 5.0
	profile.thrust_latency = 0.01
	profile.gimbal_latency = 0.02
	profile.velocity_alignment_coefficient = 0.5
	profile.auto_stabilization = false
	profile.roll_max_speed = 3.0
	profile.roll_acceleration = 8.0
	profile.roll_damping = 3.0
	return profile

# ============================================================================
# INFO
# ============================================================================

func get_info() -> String:
	"""Returns formatted string with all profile settings."""
	return """
GameProfile: %s
===============================
%s

Idle Control:
  Idle moment thrust:      %.0f%%
  
Control Latency:
  Thrust latency:          %.3f s
  Gimbal latency:          %.3f s

Aerodynamics:
  Velocity alignment:      %.2f

Roll Control:
  Roll max speed:          %.1f rad/s
  Roll acceleration:       %.1f rad/s²
  Roll damping:            %.1f
  
Assistance:
  Auto stabilization:      %s
  Stabilization strength:  %.1f
===============================
""" % [
		profile_name,
		description,
		idle_moment_thrust_percentage,
		thrust_latency,
		gimbal_latency,
		velocity_alignment_coefficient,
		roll_max_speed,
		roll_acceleration,
		roll_damping,
		"ON" if auto_stabilization else "OFF",
		stabilization_strength
	]

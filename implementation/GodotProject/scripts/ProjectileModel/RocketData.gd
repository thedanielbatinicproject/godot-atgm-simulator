extends Resource
class_name RocketData

# ============================================================================
# GODOT COORDINATE SYSTEM (NATIVE)
# ============================================================================
# X = right, Y = up, Z = forward (projectile nose)
# 
# Moments of inertia (for axisymmetric body):
#   I_xx = I_yy (larger) - pitch/yaw (around axes perpendicular to nose)
#   I_zz (smaller) - roll (around nose axis/Z)
# ============================================================================

# ============================================================================
# EXPORTED PROPERTIES
# ============================================================================

@export_category("Projectile")

@export_group("Geometry")
## Radius of the cylindrical body in meters.
@export_range(0.01, 1.0, 0.01, "suffix:m") var radius: float = 0.05
## Height of the cylindrical section in meters.
@export_range(0.01, 5.0, 0.01, "suffix:m") var cylinder_height: float = 0.3
## Height of the conical nose section in meters.
@export_range(0.01, 2.0, 0.01, "suffix:m") var cone_height: float = 0.2

@export_group("Mass")
## Total mass of the projectile in kilograms.
@export_range(0.1, 100.0, 0.1, "suffix:kg") var mass: float = 2.0

@export_group("Propulsion")
## Maximum thrust force in Newtons.
@export_range(0.0, 10000.0, 10.0, "suffix:N") var max_thrust: float = 500.0
## Maximum gimbal deflection angle.
@export_range(5.0, 50.0, 0.5, "radians_as_degrees") var max_thrust_angle: float = PI / 6.0

@export_group("Control Latency")
## Delay before thrust changes take effect (seconds).
@export_range(0.0, 1.0, 0.001, "suffix:s") var thrust_latency: float = 0.01
## Delay before gimbal changes take effect (seconds).
@export_range(0.0, 1.0, 0.001, "suffix:s") var gimbal_latency: float = 0.02

@export_group("⚠️ Aerodynamics (Advanced)")
## Aerodynamic stabilization moment coefficient (C_M,α). 
## Controls how strongly the projectile aligns with flight direction.
@export_range(0.0, 10.0, 0.1) var stabilization_moment_coefficient: float = 2.0
## Rotational damping coefficient in N·m·s/rad.
## Higher values = faster damping of angular oscillations.
@export_range(0.0, 5.0, 0.01, "suffix:N·m·s/rad") var rotational_damping_coefficient: float = 0.5

@export_group("🚫 Drag (Do Not Modify)")
## Form drag coefficient (C_D0). Determines drag at zero angle of attack.
## 🚫 DO NOT CHANGE unless you know what you're doing!
@export_range(0.0, 2.0, 0.01) var drag_coefficient_form: float = 0.2
## Viscous drag factor (k). Higher values increase drag at low Reynolds numbers.
## 🚫 DO NOT CHANGE unless you know what you're doing!
@export_range(0.0, 100000.0, 100.0) var drag_coefficient_viscous_factor: float = 10000.0

# ============================================================================
# COMPUTED PROPERTIES (not exported - calculated from geometry)
# ============================================================================

## Volume of the projectile (computed from geometry)
var volume: float:
	get:
		return PI * radius * radius * (cylinder_height + cone_height / 3.0)

## Moment of inertia around X axis (pitch)
var moment_of_inertia_xx: float = 0.0
## Moment of inertia around Y axis (yaw) - equals I_xx for axisymmetric body
var moment_of_inertia_yy: float = 0.0
## Moment of inertia around Z axis (roll) - smaller for axisymmetric body
var moment_of_inertia_zz: float = 0.0

var inertia_computed: bool = false

# ============================================================================
# INERTIA COMPUTATION
# ============================================================================

func compute_inertia():
	"""Compute moments of inertia from geometry.
	
	For Godot coordinate system (Z = nose):
	- I_zz = moment around symmetry axis (roll) - SMALLER
	- I_xx = I_yy = moment around transverse axes - LARGER
	"""
	if inertia_computed:
		return
	
	var alpha_v = cylinder_height / (cylinder_height + cone_height / 3.0)
	var alpha_s = 1.0 - alpha_v
	
	var mass_cylinder = alpha_v * mass
	var mass_cone = alpha_s * mass
	
	# I_zz = moment around symmetry axis (roll around Z/nose)
	var izz_cylinder = 0.5 * mass_cylinder * radius * radius
	var izz_cone = 0.3 * mass_cone * radius * radius
	moment_of_inertia_zz = izz_cylinder + izz_cone
	
	# Center of mass position along Z axis
	var zcm_cylinder = cylinder_height / 2.0
	var zcm_cone = cylinder_height + cone_height / 4.0
	var zcm_total = compute_center_of_mass_local()
	
	# I_xx = I_yy = moment around transverse axes (pitch/yaw)
	var ixx_cylinder = (1.0 / 12.0) * mass_cylinder * (3.0 * radius * radius + cylinder_height * cylinder_height)
	ixx_cylinder += mass_cylinder * (zcm_cylinder - zcm_total) * (zcm_cylinder - zcm_total)
	
	var ixx_cone = (3.0 / 20.0) * mass_cone * (radius * radius + 4.0 * cone_height * cone_height)
	ixx_cone += mass_cone * (zcm_cone - zcm_total) * (zcm_cone - zcm_total)
	
	moment_of_inertia_xx = ixx_cylinder + ixx_cone
	moment_of_inertia_yy = moment_of_inertia_xx  # Axisymmetric: I_xx = I_yy
	
	inertia_computed = true
	
	print("DEBUG: compute_inertia() - I_xx=%.8f, I_yy=%.8f, I_zz=%.8f" % [
		moment_of_inertia_xx, moment_of_inertia_yy, moment_of_inertia_zz])

func compute_center_of_mass_local() -> float:
	"""Center of mass position along local Z axis (nose).
	Formula: (6H² + 4Hh + 3h²) / (12H + 4h)
	"""
	var H = cylinder_height
	var h = cone_height
	return (6.0 * H * H + 4.0 * H * h + 3.0 * h * h) / (12.0 * H + 4.0 * h)

# ============================================================================
# DEBUG
# ============================================================================

func get_info() -> String:
	"""Returns formatted string with all projectile parameters."""
	compute_inertia()
	
	var info = """
RocketData
===============================
Geometry:
  Radius (R):              %.4f m
  Cylinder height (H):     %.4f m
  Cone height (h):         %.4f m
  Volume:                  %.6f m³
  
Mass & Inertia (Godot: Z=nose):
  Mass (M):                %.2f kg
  I_xx (pitch):            %.6f kg·m²
  I_yy (yaw):              %.6f kg·m²
  I_zz (roll):             %.6f kg·m²
  
Center of mass (local Z):  %.4f m
  
Propulsion:
  Max thrust:              %.1f N
  Max gimbal angle:        %.2f°
  
Latency:
  Thrust:                  %.3f s
  Gimbal:                  %.3f s
  
Aerodynamics:
  C_D0:                    %.2f
  k (viscous):             %.0f
  C_M,α (stabilization):   %.2f
  Rotational damping:      %.2f N·m·s/rad
===============================
""" % [
		radius, cylinder_height, cone_height, volume,
		mass, moment_of_inertia_xx, moment_of_inertia_yy, moment_of_inertia_zz,
		compute_center_of_mass_local(),
		max_thrust, rad_to_deg(max_thrust_angle),
		thrust_latency, gimbal_latency,
		drag_coefficient_form, drag_coefficient_viscous_factor, 
		stabilization_moment_coefficient, rotational_damping_coefficient
	]
	
	return info

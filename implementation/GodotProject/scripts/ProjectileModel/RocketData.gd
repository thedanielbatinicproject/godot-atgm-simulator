extends Resource
class_name RocketData

# GEOMETRIJA PROJEKTILA
@export var radius: float = 0.05
@export var cylinder_height: float = 0.3
@export var cone_height: float = 0.2

# MASA I VOLUMEN
@export var mass: float = 2.0

var volume: float:
	get:
		return PI * radius * radius * (cylinder_height + cone_height / 3.0)

# MOMENTI TROMOSTI (izračunavaju se automatski iz geometrije)
var moment_of_inertia_xx: float = 0.0
var moment_of_inertia_yy: float = 0.0

var inertia_computed: bool = false

func compute_inertia():
	"""Izračunaj momente tromosti iz geometrije prema modelu."""
	if inertia_computed:
		return
	
	var alpha_v = cylinder_height / (cylinder_height + cone_height / 3.0)
	var alpha_s = 1.0 - alpha_v
	
	var mass_cylinder = alpha_v * mass
	var mass_cone = alpha_s * mass
	
	var ixx_cylinder = 0.5 * mass_cylinder * radius * radius
	var ixx_cone = 0.3 * mass_cone * radius * radius
	moment_of_inertia_xx = ixx_cylinder + ixx_cone
	
	var xcm_cylinder = cylinder_height / 2.0
	var xcm_cone = cylinder_height + cone_height / 4.0
	var xcm_total = compute_center_of_mass_local()
	
	var iyy_cylinder = (1.0 / 12.0) * mass_cylinder * (3.0 * radius * radius + cylinder_height * cylinder_height)
	iyy_cylinder += mass_cylinder * (xcm_cylinder - xcm_total) * (xcm_cylinder - xcm_total)
	
	var iyy_cone = (3.0 / 20.0) * mass_cone * (radius * radius + 4.0 * cone_height * cone_height)
	#u modelu je zadano H + h/4 - x_cm_total, međutim xcm_cone = H + h/4
	iyy_cone += mass_cone * (xcm_cone - xcm_total) * (xcm_cone - xcm_total)
	
	moment_of_inertia_yy = iyy_cylinder + iyy_cone
	inertia_computed = true
	
	print("DEBUG: compute_inertia() - I_xx=%.8f, I_yy=%.8f, mass=%.2f, R=%.3f, H=%.3f, h=%.3f" % [moment_of_inertia_xx, moment_of_inertia_yy, mass, radius, cylinder_height, cone_height])

func compute_center_of_mass_local() -> float:
	"""pozicija težišta duž lokalne x-osi: (6H² + 4Hh + 3h²) / (12H + 4h)."""
	var H = cylinder_height
	var h = cone_height
	return (6.0 * H * H + 4.0 * H * h + 3.0 * h * h) / (12.0 * H + 4.0 * h)

# POTISNA SILA
@export var max_thrust: float = 500.0
@export var max_thrust_angle: float = PI / 6.0

# LATENCIJE INPUTA
@export var thrust_latency: float = 0.01
@export var gimbal_latency: float = 0.02

# AERODINAMIKA
@export var drag_coefficient_form: float = 0.2
@export var drag_coefficient_viscous_factor: float = 10000.0
@export var stabilization_moment_coefficient: float = 2.0  # C_M,α - direktno iz model.latex (linija 650)

# INICIJALIZACIJA

func _init(p_radius: float = 0.05, p_cyl_h: float = 0.3, p_cone_h: float = 0.2, 
		   p_mass: float = 2.0, p_max_thrust: float = 500.0):
	radius = p_radius
	cylinder_height = p_cyl_h
	cone_height = p_cone_h
	mass = p_mass
	max_thrust = p_max_thrust
	compute_inertia()

func _post_initialize():
	"""resetira i ponovno izračunava momente tromosti."""
	inertia_computed = false
	compute_inertia()

# DEBUG

func get_info() -> String:
	"""vraća formatiran string sa svim parametrima."""
	compute_inertia()
	
	var info = """
Projektil - RocketData
===============================
Geometrija:
  Radijus (R):             %.4f m
  Visina valjka (H):       %.4f m
  Visina stošca (h):       %.4f m
  Volumen:                 %.6f m³
  
Masa i tromosti:
  Masa (M):                %.2f kg
  Ixx:                     %.6f kg·m²
  Iyy:                     %.6f kg·m²
  
Težište (lokalno):         %.4f m
  
Potisna sila:
  Maksimalna sila:         %.1f N
  Max kut defleksije:      %.2f °
  
Latencije:
  Throttle:                %.3f s
  Gimbal:                  %.3f s
  
Aerodinamika:
  C_D0:                    %.2f
  k:                       %.0f
  C_M,α:                   %.2f
===============================
""" % [
		radius, cylinder_height, cone_height, volume,
		mass, moment_of_inertia_xx, moment_of_inertia_yy,
		compute_center_of_mass_local(),
		max_thrust, rad_to_deg(max_thrust_angle),
		thrust_latency, gimbal_latency,
		drag_coefficient_form, drag_coefficient_viscous_factor, stabilization_moment_coefficient
	]
	
	return info

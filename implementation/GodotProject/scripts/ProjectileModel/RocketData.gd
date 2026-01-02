extends Resource
class_name RocketData

# ============================================================================
# GODOT KOORDINATNI SUSTAV (NATIVNI)
# ============================================================================
# X = desno, Y = gore, Z = naprijed (nos projektila)
# 
# Momenti tromosti (za osnosimetrično tijelo):
#   I_xx = I_yy (veći) - pitch/yaw (oko osi okomitih na nos)
#   I_zz (manji) - roll (oko osi nosa/Z)
# ============================================================================

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
# Godot sustav: Z = nos, pa I_zz je roll (manji), I_xx = I_yy su pitch/yaw (veći)
var moment_of_inertia_xx: float = 0.0  # pitch (oko X)
var moment_of_inertia_yy: float = 0.0  # yaw (oko Y), = I_xx za osnosimetrično
var moment_of_inertia_zz: float = 0.0  # roll (oko Z/nosa, manji)

var inertia_computed: bool = false

func compute_inertia():
	"""Izračunaj momente tromosti iz geometrije.
	
	Za Godot sustav (Z = nos):
	- I_zz = moment oko osi simetrije (roll) - MANJI
	- I_xx = I_yy = moment oko poprečnih osi - VEĆI
	"""
	if inertia_computed:
		return
	
	var alpha_v = cylinder_height / (cylinder_height + cone_height / 3.0)
	var alpha_s = 1.0 - alpha_v
	
	var mass_cylinder = alpha_v * mass
	var mass_cone = alpha_s * mass
	
	# I_zz = moment oko osi simetrije (roll oko Z/nosa)
	# Za valjak: (1/2) * m * R²
	# Za stožac: (3/10) * m * R²
	var izz_cylinder = 0.5 * mass_cylinder * radius * radius
	var izz_cone = 0.3 * mass_cone * radius * radius
	moment_of_inertia_zz = izz_cylinder + izz_cone
	
	# Pozicija težišta duž Z osi (nos)
	var zcm_cylinder = cylinder_height / 2.0
	var zcm_cone = cylinder_height + cone_height / 4.0
	var zcm_total = compute_center_of_mass_local()
	
	# I_xx = I_yy = moment oko poprečnih osi (pitch/yaw)
	# Koristi paralelne osi teorem
	var ixx_cylinder = (1.0 / 12.0) * mass_cylinder * (3.0 * radius * radius + cylinder_height * cylinder_height)
	ixx_cylinder += mass_cylinder * (zcm_cylinder - zcm_total) * (zcm_cylinder - zcm_total)
	
	# Za stožac: (3/80) * m * (4R² + h²) je točnije, ali model koristi (3/20)
	var ixx_cone = (3.0 / 20.0) * mass_cone * (radius * radius + 4.0 * cone_height * cone_height)
	ixx_cone += mass_cone * (zcm_cone - zcm_total) * (zcm_cone - zcm_total)
	
	moment_of_inertia_xx = ixx_cylinder + ixx_cone
	moment_of_inertia_yy = moment_of_inertia_xx  # osnosimetrija: I_xx = I_yy
	
	inertia_computed = true
	
	print("DEBUG: compute_inertia() - I_xx=%.8f, I_yy=%.8f, I_zz=%.8f" % [
		moment_of_inertia_xx, moment_of_inertia_yy, moment_of_inertia_zz])

func compute_center_of_mass_local() -> float:
	"""Pozicija težišta duž lokalne Z osi (nos).
	Formula: (6H² + 4Hh + 3h²) / (12H + 4h)
	"""
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
  
Masa i tromosti (Godot: Z=nos):
  Masa (M):                %.2f kg
  I_xx (pitch):            %.6f kg·m²
  I_yy (yaw):              %.6f kg·m²
  I_zz (roll):             %.6f kg·m²
  
Težište (lokalno Z):       %.4f m
  
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
		mass, moment_of_inertia_xx, moment_of_inertia_yy, moment_of_inertia_zz,
		compute_center_of_mass_local(),
		max_thrust, rad_to_deg(max_thrust_angle),
		thrust_latency, gimbal_latency,
		drag_coefficient_form, drag_coefficient_viscous_factor, stabilization_moment_coefficient
	]
	
	return info

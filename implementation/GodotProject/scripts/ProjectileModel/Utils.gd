extends Node
class_name Utils

# ============================================================================
# KOORDINATNI SUSTAVI
# ============================================================================
# 
# MODEL.LATEX (aerospace konvencija):
#   X = naprijed (nos projektila)
#   Y = desno
#   Z = gore
#
# GODOT (Y-up konvencija):
#   X = desno
#   Y = gore  
#   Z = naprijed (ali prema kameri, dakle -Z je "naprijed" u sceni)
#
# KONVERZIJA: Model → Godot
#   model_x → -godot_z  (naprijed)
#   model_y →  godot_x  (desno)
#   model_z →  godot_y  (gore)
#
# KONVERZIJA: Godot → Model
#   godot_x →  model_y
#   godot_y →  model_z
#   godot_z → -model_x
# ============================================================================

# KONFIGURACIJA
var rocket_data: RocketData

# INICIJALIZACIJA

func _init(p_rocket_data: RocketData = null):
	rocket_data = p_rocket_data

# ============================================================================
# KONVERZIJE KOORDINATNIH SUSTAVA
# ============================================================================

static func model_to_godot(v: Vector3) -> Vector3:
	"""Konvertira vektor iz Model.latex sustava u Godot sustav."""
	# model(x,y,z) → godot(-z, y, x) ... wait, let me think again
	# model_x (naprijed) → godot -Z
	# model_y (desno) → godot X  
	# model_z (gore) → godot Y
	return Vector3(v.y, v.z, -v.x)

static func godot_to_model(v: Vector3) -> Vector3:
	"""Konvertira vektor iz Godot sustava u Model.latex sustav."""
	# godot(x,y,z) → model(-z, x, y)
	# godot_x (desno) → model_y
	# godot_y (gore) → model_z
	# godot_z (naprijed) → -model_x
	return Vector3(-v.z, v.x, v.y)

static func model_basis_to_godot(b: Basis) -> Basis:
	"""Konvertira Basis iz Model sustava u Godot sustav."""
	var x = model_to_godot(b.x)
	var y = model_to_godot(b.y)
	var z = model_to_godot(b.z)
	return Basis(x, y, z)

# ============================================================================
# ROTACIJSKA MATRICA
# ============================================================================

func euler_to_rotation_matrix(alpha: float, beta: float, gamma: float) -> Basis:
	"""konvertira Eulerove kutove u rotacijsku matricu (lokalno -> globalno) u MODEL koordinatama.
	Koristi se u svim fizičkim izračunima (sile, momenti).
	"""
	var cos_a = cos(alpha)
	var sin_a = sin(alpha)
	var cos_b = cos(beta)
	var sin_b = sin(beta)
	var cos_g = cos(gamma)
	var sin_g = sin(gamma)
	
	# Rotacijska matrica u Model koordinatama (X=naprijed, Y=desno, Z=gore)
	var x_axis = Vector3(
		cos_b * cos_g,
		cos_b * sin_g,
		-sin_b
	)
	
	var y_axis = Vector3(
		sin_a * sin_b * cos_g - cos_a * sin_g,
		sin_a * sin_b * sin_g + cos_a * cos_g,
		sin_a * cos_b
	)
	
	var z_axis = Vector3(
		sin_a * sin_g + cos_a * sin_b * cos_g,
		cos_a * sin_b * sin_g - sin_a * cos_g,
		cos_a * cos_b
	)
	
	return Basis(x_axis, y_axis, z_axis)

func euler_to_rotation_matrix_godot(alpha: float, beta: float, gamma: float) -> Basis:
	"""konvertira Eulerove kutove u rotacijsku matricu za GODOT prikaz.
	Koristi se samo za vizualizaciju u Godot sceni.
	"""
	var model_basis = euler_to_rotation_matrix(alpha, beta, gamma)
	return model_basis_to_godot(model_basis)

# TRANSFORMACIJE

func get_direction_vector(_alpha: float, beta: float, gamma: float) -> Vector3:
	"""jedinični vektor smjera projektila (lokalna x-os) u globalnom Model sustavu.
	Vraća smjer u Model koordinatama (X=naprijed, Y=desno, Z=gore).
	"""
	# Ovo je smjer u Model koordinatama - X je naprijed
	return Vector3(
		cos(beta) * cos(gamma),
		cos(beta) * sin(gamma),
		-sin(beta)
	)

func get_center_of_mass_position(ref_position: Vector3, alpha: float, beta: float, gamma: float) -> Vector3:
	"""globalna pozicija težišta iz pozicije baze valjka."""
	if not rocket_data:
		return ref_position
	
	var xcm_local = rocket_data.compute_center_of_mass_local()
	var direction = get_direction_vector(alpha, beta, gamma)
	
	return ref_position + direction * xcm_local

func transform_local_to_global(local_vector: Vector3, alpha: float, beta: float, gamma: float) -> Vector3:
	"""transformira vektor iz lokalnog u globalni sustav."""
	var rotation_matrix = euler_to_rotation_matrix(alpha, beta, gamma)
	return rotation_matrix * local_vector

func transform_global_to_local(global_vector: Vector3, alpha: float, beta: float, gamma: float) -> Vector3:
	"""transformira vektor iz globalnog u lokalni sustav."""
	var rotation_matrix = euler_to_rotation_matrix(alpha, beta, gamma)
	return rotation_matrix.inverse() * global_vector

# EULEROVI KUTOVI

func angular_velocity_to_euler_derivatives(
	alpha: float, 
	beta: float, 
	_gamma: float,
	omega_local: Vector3
) -> Vector3:
	"""konvertira lokalnu kutnu brzinu u derivacije Eulerovih kutova."""
	var sin_a = sin(alpha)
	var cos_a = cos(alpha)
	var tan_b = tan(beta)
	var cos_b = cos(beta)
	
	var wx = omega_local.x
	var wy = omega_local.y
	var wz = omega_local.z
	
	var dalpha_dt = wx + tan_b * (wy * sin_a + wz * cos_a)
	var dbeta_dt = wy * cos_a - wz * sin_a
	var dgamma_dt = (wy * sin_a + wz * cos_a) / cos_b if abs(cos_b) > 0.001 else 0.0
	
	return Vector3(dalpha_dt, dbeta_dt, dgamma_dt)

# KUTOVI IZMEĐU VEKTORA

func angle_between_vectors(v1: Vector3, v2: Vector3) -> float:
	"""izračuna kut između dva vektora (rad)."""
	var dot_product = v1.dot(v2)
	var magnitudes = v1.length() * v2.length()
	
	if magnitudes < 0.0001:
		return 0.0
	
	var cos_angle = clamp(dot_product / magnitudes, -1.0, 1.0)
	return acos(cos_angle)

# DEBUG

func get_utils_info() -> String:
	var info = """
Utils - Transformacije:
==========================================
+ euler_to_rotation_matrix()
+ get_direction_vector()
+ get_center_of_mass_position()
+ transform_local_to_global()
+ transform_global_to_local()
+ angular_velocity_to_euler_derivatives()
+ angle_between_vectors()
==========================================
"""
	return info

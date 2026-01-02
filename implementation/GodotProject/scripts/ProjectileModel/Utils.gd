extends Node
class_name Utils

# ============================================================================
# GODOT KOORDINATNI SUSTAV (NATIVNI)
# ============================================================================
# 
# GODOT (prilagođeno za projektil):
#   X = desno (krilo desno)
#   Y = gore
#   Z = naprijed (nos projektila)
#
# EULEROVI KUTOVI (avionska konvencija):
#   α (alpha) = pitch - rotacija oko X osi (nos gore/dolje)
#   β (beta)  = yaw   - rotacija oko Y osi (nos lijevo/desno)  
#   γ (gamma) = roll  - rotacija oko Z osi (rotacija oko nosa)
#
# MOMENTI TROMOSTI:
#   I_xx = I_yy (veći, oko X i Y osi) - pitch/yaw
#   I_zz (manji, oko Z osi/osi nosa) - roll
#
# LOKALNI SUSTAV PROJEKTILA:
#   Lokalna Z os = naprijed (smjer nosa)
#   Lokalna X os = desno
#   Lokalna Y os = gore
#   Ishodište = središte baze valjka (gdje je propulzor)
# ============================================================================

# KONFIGURACIJA
var rocket_data: RocketData

# INICIJALIZACIJA

func _init(p_rocket_data: RocketData = null):
	rocket_data = p_rocket_data

# ============================================================================
# ROTACIJSKA MATRICA
# ============================================================================

func euler_to_rotation_matrix(alpha: float, beta: float, gamma: float) -> Basis:
	"""
	Konvertira Eulerove kutove u rotacijsku matricu (lokalno -> globalno).
	
	Redoslijed rotacija: Z-Y-X (roll-yaw-pitch)
	  1. Roll (γ) oko Z osi
	  2. Yaw (β) oko Y osi  
	  3. Pitch (α) oko X osi
	
	Ovo daje matricu R = Rx(α) * Ry(β) * Rz(γ)
	"""
	var cos_a = cos(alpha)  # pitch
	var sin_a = sin(alpha)
	var cos_b = cos(beta)   # yaw
	var sin_b = sin(beta)
	var cos_g = cos(gamma)  # roll
	var sin_g = sin(gamma)
	
	# Rotacijska matrica R = Rx(α) * Ry(β) * Rz(γ)
	# Kolone su lokalne osi izražene u globalnom sustavu
	
	# X os (desno) u globalnom sustavu
	var x_axis = Vector3(
		cos_b * cos_g,
		sin_a * sin_b * cos_g + cos_a * sin_g,
		-cos_a * sin_b * cos_g + sin_a * sin_g
	)
	
	# Y os (gore) u globalnom sustavu
	var y_axis = Vector3(
		-cos_b * sin_g,
		-sin_a * sin_b * sin_g + cos_a * cos_g,
		cos_a * sin_b * sin_g + sin_a * cos_g
	)
	
	# Z os (naprijed/nos) u globalnom sustavu
	var z_axis = Vector3(
		sin_b,
		-sin_a * cos_b,
		cos_a * cos_b
	)
	
	return Basis(x_axis, y_axis, z_axis)

# ============================================================================
# TRANSFORMACIJE
# ============================================================================

func get_direction_vector(alpha: float, beta: float, _gamma: float) -> Vector3:
	"""
	Jedinični vektor smjera projektila (lokalna Z os = nos) u globalnom sustavu.
	
	Ovo je treća kolona rotacijske matrice (Z os).
	Za nos projektila koji gleda u +Z:
	  - beta=0, alpha=0: nos gleda u +Z (naprijed)
	  - beta>0: nos skreće udesno (+X)
	  - alpha>0: nos ide gore (+Y)
	"""
	var cos_a = cos(alpha)
	var sin_a = sin(alpha)
	var cos_b = cos(beta)
	var sin_b = sin(beta)
	
	return Vector3(
		sin_b,           # X komponenta (yaw utječe)
		-sin_a * cos_b,  # Y komponenta (pitch utječe)
		cos_a * cos_b    # Z komponenta (naprijed)
	)

func get_center_of_mass_position(ref_position: Vector3, alpha: float, beta: float, gamma: float) -> Vector3:
	"""
	Globalna pozicija težišta iz pozicije baze valjka.
	Težište je pomaknuto duž lokalne Z osi (osi nosa).
	"""
	if not rocket_data:
		return ref_position
	
	var zcm_local = rocket_data.compute_center_of_mass_local()
	var direction = get_direction_vector(alpha, beta, gamma)
	
	return ref_position + direction * zcm_local

func transform_local_to_global(local_vector: Vector3, alpha: float, beta: float, gamma: float) -> Vector3:
	"""Transformira vektor iz lokalnog u globalni sustav."""
	var rotation_matrix = euler_to_rotation_matrix(alpha, beta, gamma)
	return rotation_matrix * local_vector

func transform_global_to_local(global_vector: Vector3, alpha: float, beta: float, gamma: float) -> Vector3:
	"""Transformira vektor iz globalnog u lokalni sustav."""
	var rotation_matrix = euler_to_rotation_matrix(alpha, beta, gamma)
	return rotation_matrix.inverse() * global_vector

# ============================================================================
# EULEROVI KUTOVI - KINEMATIČKE RELACIJE
# ============================================================================

func angular_velocity_to_euler_derivatives(
	alpha: float, 
	beta: float, 
	_gamma: float,
	omega_local: Vector3
) -> Vector3:
	"""
	Konvertira lokalnu kutnu brzinu u derivacije Eulerovih kutova.
	
	omega_local = (ωx, ωy, ωz) u lokalnom sustavu
	  ωx = kutna brzina oko lokalne X osi (pitch rate)
	  ωy = kutna brzina oko lokalne Y osi (yaw rate)
	  ωz = kutna brzina oko lokalne Z osi (roll rate)
	
	Vraća (α̇, β̇, γ̇) = (pitch_dot, yaw_dot, roll_dot)
	"""
	var sin_a = sin(alpha)
	var cos_a = cos(alpha)
	var cos_b = cos(beta)
	var tan_b = tan(beta)
	
	var wx = omega_local.x  # pitch rate (lokalno)
	var wy = omega_local.y  # yaw rate (lokalno)
	var wz = omega_local.z  # roll rate (lokalno)
	
	# Kinematičke relacije za Z-Y-X Euler kutove
	var dalpha_dt = wx + tan_b * (wy * sin_a + wz * cos_a)
	var dbeta_dt = wy * cos_a - wz * sin_a
	var dgamma_dt = (wy * sin_a + wz * cos_a) / cos_b if abs(cos_b) > 0.001 else 0.0
	
	return Vector3(dalpha_dt, dbeta_dt, dgamma_dt)

# ============================================================================
# POMOĆNE FUNKCIJE
# ============================================================================

func angle_between_vectors(v1: Vector3, v2: Vector3) -> float:
	"""Izračunava kut između dva vektora (radijani)."""
	var dot_product = v1.dot(v2)
	var magnitudes = v1.length() * v2.length()
	
	if magnitudes < 0.0001:
		return 0.0
	
	var cos_angle = clamp(dot_product / magnitudes, -1.0, 1.0)
	return acos(cos_angle)

# ============================================================================
# DEBUG
# ============================================================================

func get_utils_info() -> String:
	return """
Utils - Godot Native Koordinatni Sustav
==========================================
Osi: X=desno, Y=gore, Z=naprijed(nos)
Kutovi: α=pitch(X), β=yaw(Y), γ=roll(Z)

Funkcije:
+ euler_to_rotation_matrix(α, β, γ)
+ get_direction_vector(α, β, γ)
+ get_center_of_mass_position()
+ transform_local_to_global()
+ transform_global_to_local()
+ angular_velocity_to_euler_derivatives()
+ angle_between_vectors()
==========================================
"""

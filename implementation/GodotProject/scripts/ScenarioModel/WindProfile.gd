class_name WindProfile

# SVEUČILIŠTE WIND FUNKCIJA ZA RAZLIČITE SCENARIJE

# KONSTANTAN VJETAR
static func constant_wind(wind_vector: Vector3) -> Callable:
	"""vjetar je konstantan vektor u cijelom prostoru."""
	return func(_pos: Vector3) -> Vector3:
		return wind_vector

# VJETAR SA GRADIJENTOM PO VISINI (Z-OS)
static func linear_altitude_wind(base_wind: Vector3, altitude_gradient: float) -> Callable:
	"""vjetar jači što je viša pozicija: wind += altitude_gradient * z."""
	return func(pos: Vector3) -> Vector3:
		return base_wind + Vector3(0, 0, altitude_gradient) * pos.z

# SINUSOIDNI VJETAR SA VIŠE FREKVENCIJA
static func sinusoidal_wind(amplitudes: Vector3, frequencies: Vector3) -> Callable:
	"""vjetar koji se mjenja kao sinusne funkcije po prostoru."""
	return func(pos: Vector3) -> Vector3:
		return Vector3(
			amplitudes.x * sin(frequencies.x * pos.x),
			amplitudes.y * sin(frequencies.y * pos.y),
			amplitudes.z * sin(frequencies.z * pos.z)
		)

# VORTEX VJETAR
static func vortex_wind(center: Vector3, strength: float, axis: Vector3 = Vector3.UP) -> Callable:
	"""vjetarsko polje koje se vrti oko točke."""
	var normalized_axis = axis.normalized()
	return func(pos: Vector3) -> Vector3:
		var offset = pos - center
		var tangent = normalized_axis.cross(offset).normalized()
		return tangent * strength * (1.0 / (1.0 + offset.length()))

# KOMBINIRAN VJETAR
static func combined_wind(wind_functions: Array) -> Callable:
	"""zbraja više vjetarskih funkcija."""
	return func(pos: Vector3) -> Vector3:
		var result = Vector3.ZERO
		for wind_func in wind_functions:
			result += wind_func.call(pos)
		return result

# VJETAR SA TURBULENCIJOM (PERLIN-LIKE PRIMJENA)
static func turbulent_wind(base_wind: Vector3, turbulence_scale: float) -> Callable:
	"""osnovni vjetar sa pseudo-random perturbacijama."""
	return func(pos: Vector3) -> Vector3:
		# grobi priblizni "Perlin-like" šum koristeći sin i cos
		var noise = sin(pos.x * 0.5) * cos(pos.y * 0.3) * sin(pos.z * 0.7)
		return base_wind + Vector3.ONE * noise * turbulence_scale

# VJETAR SA GRADIJENTOM PO SVIM OSAMA
static func full_gradient_wind(base_wind: Vector3, gradient: Vector3) -> Callable:
	"""vjetar sa sveobuhvatnim gradijentom."""
	return func(pos: Vector3) -> Vector3:
		return base_wind + gradient * pos

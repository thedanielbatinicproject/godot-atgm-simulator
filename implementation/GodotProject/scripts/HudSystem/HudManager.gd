extends CanvasLayer
class_name HudManager

# ============================================================================
# HUD MANAGER
# ============================================================================
# Glavni upravitelj HUD-a. Pronalazi Projectile i ažurira sve HUD elemente.
# ============================================================================

# Reference na HUD komponente (postavljaju se u _ready)
@onready var thrust_bar: ThrustBar = $ThrustBar

# Reference na simulaciju
var projectile: Projectile = null
var guidance: Guidance = null

func _ready():
	# Pronađi Projectile u sceni
	await get_tree().process_frame  # Čekaj da se scena učita
	_find_projectile()

func _find_projectile():
	"""Pronađi Projectile node u sceni."""
	var root = get_tree().root
	projectile = _find_node_by_class(root, "Projectile")
	
	if projectile:
		# Dohvati Guidance iz Projectile-a
		guidance = projectile.guidance
		print("[HudManager] Connected to Projectile")
	else:
		push_warning("[HudManager] Projectile not found!")

func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	"""Rekurzivno traži node po class_name."""
	if node.get_script() and node.get_script().get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var found = _find_node_by_class(child, class_name_str)
		if found:
			return found
	return null

func _process(_delta: float):
	if not projectile or not guidance:
		return
	
	# Ažuriraj thrust bar
	if thrust_bar:
		thrust_bar.set_thrust_value(guidance.throttle_input)

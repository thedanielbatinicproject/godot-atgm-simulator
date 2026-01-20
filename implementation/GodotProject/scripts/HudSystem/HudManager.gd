extends CanvasLayer
class_name HudManager

# Node references (updated via @onready)
@onready var margin_container: MarginContainer = $BoxContainer/VBoxContainer/DistanceToTank/MarginContainer
@onready var coordinates: Label = $BoxContainer/VBoxContainer/BoxContainer2/VBoxContainer/XYZ/HBoxContainer/BoxContainer/MarginContainer/Coordinates
@onready var angles: Label = $BoxContainer/VBoxContainer/BoxContainer2/VBoxContainer/XYZ/HBoxContainer/BoxContainer2/BoxContainer/MarginContainer/Angles
@onready var distance_label: Label = $BoxContainer/VBoxContainer/BoxContainer2/VBoxContainer/BoxContainer4/HBoxContainer/BoxContainer/MarginContainer/Distance
@onready var projected_time: Label = $BoxContainer/VBoxContainer/BoxContainer2/VBoxContainer/BoxContainer4/HBoxContainer/BoxContainer2/BoxContainer/MarginContainer/ProjectedTime
@onready var point_arrow: Sprite2D = $BoxContainer/VBoxContainer/BoxContainer2/VBoxContainer/BoxContainer2/MarginContainer/BoxContainer/PointArrow

# ============================================================================
# HUD MANAGER
# ============================================================================
# Main HUD controller. Finds Projectile and updates all HUD elements.
# ============================================================================

# HUD component references (set in _ready)
@onready var thrust_bar: ThrustBar = $BoxContainer/VBoxContainer/BoxContainer3/MarginContainer/ThrustBar

# Distance bar - created dynamically
var distance_bar: DistanceBar = null

# Simulation references
var projectile: Projectile = null
var guidance: Guidance = null
var tank: Node3D = null

# Projectile tracking
var initial_distance: float = 0.0
var _initialized: bool = false

# Timing for updates (every 0.5s for coordinates/angles/time)
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.5

func _ready():
	# Find Projectile and Tank in scene
	await get_tree().process_frame  # Wait for scene to load
	_find_projectile()
	_find_tank()
	_create_distance_bar()
	_initialize_distances()

func _find_projectile():
	"""Find Projectile node in scene."""
	var root = get_tree().root
	projectile = _find_node_by_class(root, "Projectile")
	
	if projectile:
		# Get Guidance from Projectile
		guidance = projectile.guidance
		print("[HudManager] Connected to Projectile")
	else:
		push_warning("[HudManager] Projectile not found!")

func _find_tank():
	"""Find Tank node in scene (target)."""
	var root = get_tree().root
	
	# Method 1: Look for a node named exactly "Tank" anywhere in the scene
	var found_node = _find_node_by_exact_name(root, "Tank")
	
	# Method 2: Try finding by partial name match
	if not found_node:
		found_node = _find_node_by_name(root, "Tank")
	if not found_node:
		found_node = _find_node_by_name(root, "TankTarget")
	
	# Method 3: Try finding any node in "targets" group
	if not found_node:
		var targets = get_tree().get_nodes_in_group("targets")
		if targets.size() > 0:
			found_node = targets[0]
	
	# Method 4: Look for a node with "tank" in name that has a collision shape (is the actual tank)
	if not found_node:
		found_node = _find_tank_with_collider(root)
	
	# Cast to Node3D if valid
	if found_node and found_node is Node3D:
		tank = found_node as Node3D
		print("[HudManager] Connected to Tank target: ", tank.name)
	else:
		push_warning("[HudManager] Tank target not found!")

func _find_node_by_exact_name(node: Node, exact_name: String) -> Node:
	"""Recursively search for node by exact name."""
	if node.name == exact_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_exact_name(child, exact_name)
		if found:
			return found
	return null

func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	"""Recursively search for node by class_name."""
	if node.get_script() and node.get_script().get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var found = _find_node_by_class(child, class_name_str)
		if found:
			return found
	return null

func _find_node_by_name(node: Node, name_pattern: String) -> Node:
	"""Recursively search for node by name (case insensitive contains)."""
	if name_pattern.to_lower() in node.name.to_lower():
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, name_pattern)
		if found:
			return found
	return null

func _find_tank_with_collider(node: Node) -> Node:
	"""Find a node with 'tank' in name that has a collision shape child (the actual tank)."""
	if "tank" in node.name.to_lower() and node is Node3D:
		# Check if it has a collision shape child
		for child in node.get_children():
			if child is CollisionShape3D or child is Area3D:
				return node
	for child in node.get_children():
		var found = _find_tank_with_collider(child)
		if found:
			return found
	return null

func _create_distance_bar():
	"""Create DistanceBar inside margin_container."""
	if not margin_container:
		push_warning("[HudManager] margin_container not found for DistanceBar")
		return
	
	distance_bar = DistanceBar.new()
	distance_bar.name = "DistanceBar"
	distance_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distance_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	distance_bar.padding_percent = 0.0
	distance_bar.label_text = "DST"
	distance_bar.label_font_size = 12
	
	# Try to use same font as ThrustBar
	if thrust_bar and thrust_bar.label_font:
		distance_bar.label_font = thrust_bar.label_font
	
	margin_container.add_child(distance_bar)
	print("[HudManager] DistanceBar created")

func _initialize_distances():
	"""Calculate and set initial distance between projectile and tank."""
	await get_tree().process_frame  # Wait for positions to be set
	
	if projectile and tank:
		initial_distance = projectile.global_position.distance_to(tank.global_position)
		if distance_bar:
			distance_bar.set_initial_distance(initial_distance)
		_initialized = true
		print("[HudManager] Initial distance: %.1fm" % initial_distance)

func _process(delta: float):
	if not projectile:
		return
	
	# Update thrust bar (realtime - needs responsive feedback)
	_update_thrust_bar()
	
	# Update distance bar (realtime)
	_update_distance_bar()
	
	# Update point arrow (realtime - needs to track tank direction)
	_update_point_arrow()
	
	# Update other displays every 0.5s (coordinates, angles, distance, time)
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_coordinates()
		_update_angles()
		_update_distance()
		_update_projected_time()

func _update_coordinates():
	"""Update coordinates label with X/Y/Z position (rounded to integers)."""
	if not coordinates or not projectile:
		return
	
	var pos = projectile.global_position
	coordinates.text = "X: %d | Y: %d | Z: %d" % [roundi(pos.x), roundi(pos.y), roundi(pos.z)]

func _update_angles():
	"""Update angles label with Pitch/Yaw/Roll."""
	if not angles or not projectile or not projectile.state:
		return
	
	var state = projectile.state
	# Convert radians to degrees
	var pitch_deg = rad_to_deg(state.alpha)
	var yaw_deg = rad_to_deg(state.beta)
	var roll_deg = rad_to_deg(state.gamma)
	
	angles.text = "Pitch: %+.0f° | Yaw: %+.0f° | Roll: %+.0f°" % [pitch_deg, yaw_deg, roll_deg]

func _update_distance():
	"""Update distance label with distance to target."""
	if not distance_label:
		return
	
	var dist = _get_current_distance()
	distance_label.text = "Distance to target: %06.1fm" % dist

func _update_thrust_bar():
	"""Update thrust bar with current throttle input."""
	if not thrust_bar or not guidance:
		return
	thrust_bar.set_thrust_value(guidance.throttle_input)

func _update_distance_bar():
	"""Update distance bar with current distance to tank."""
	if not distance_bar or not _initialized:
		return
	
	var dist = _get_current_distance()
	distance_bar.set_current_distance(dist)

func _update_projected_time():
	"""Calculate and update estimated time to impact."""
	if not projected_time or not projectile or not tank:
		projected_time.text = "Estimated duration until impact: --s"
		return
	
	var time_estimate = _calculate_time_to_impact()
	
	if time_estimate < 0:
		projected_time.text = "Estimated duration until impact: --s"
	elif time_estimate > 999:
		projected_time.text = "Estimated duration until impact: >999s"
	else:
		projected_time.text = "Estimated duration until impact: %ds" % roundi(time_estimate)

func _get_current_distance() -> float:
	"""Get current distance between projectile and tank."""
	if not projectile or not tank:
		return 0.0
	return projectile.global_position.distance_to(tank.global_position)

func _calculate_time_to_impact() -> float:
	"""
	Calculate approximate time until projectile reaches tank.
	Takes into account:
	- Current distance
	- Projectile velocity (speed and direction)
	- Orientation relative to target
	- Current thrust input
	"""
	if not projectile or not tank or not projectile.state:
		return -1.0
	
	var state = projectile.state
	var proj_pos = projectile.global_position
	var tank_pos = tank.global_position
	
	# Vector from projectile to tank
	var to_target = tank_pos - proj_pos
	var distance = to_target.length()
	
	if distance < 1.0:
		return 0.0  # Already at target
	
	var to_target_normalized = to_target.normalized()
	
	# Current velocity
	var velocity = state.velocity
	var speed = velocity.length()
	
	if speed < 0.1:
		# Projectile not moving much, estimate based on potential thrust
		if guidance and guidance.throttle_input > 0.1:
			# Assume it will accelerate
			var rocket_data = projectile.scenario_data.rocket_data if projectile.scenario_data else null
			if rocket_data:
				var max_thrust = rocket_data.max_thrust
				var mass = rocket_data.total_mass
				var accel = max_thrust / mass * guidance.throttle_input
				# Use kinematic equation: d = 0.5 * a * t^2 => t = sqrt(2d/a)
				if accel > 0:
					return sqrt(2.0 * distance / accel)
		return -1.0  # Cannot estimate
	
	# Calculate closing velocity (how fast we're approaching target)
	var velocity_normalized = velocity.normalized()
	var closing_speed = velocity.dot(to_target_normalized)
	
	if closing_speed <= 0:
		# Moving away from target or perpendicular
		# Factor in orientation - how much we need to turn
		var facing_direction = projectile.global_transform.basis.z  # Forward direction
		var alignment = facing_direction.dot(to_target_normalized)
		
		if alignment > 0.5:
			# Facing towards target, will likely accelerate towards it
			# Estimate based on current speed and distance
			var estimated_avg_speed = speed * 0.5  # Conservative estimate
			if estimated_avg_speed > 0:
				return distance / estimated_avg_speed * 2.0  # Factor for turning
		
		# Not well aligned, return high estimate
		return distance / maxf(speed * 0.25, 1.0)
	
	# Simple estimate: distance / closing_speed
	var base_time = distance / closing_speed
	
	# Adjust for thrust - if thrusting, we'll likely go faster
	if guidance and guidance.throttle_input > 0.5:
		# With thrust, estimate slightly faster
		base_time *= 0.85
	elif guidance and guidance.throttle_input < 0.1:
		# Decelerating (drag), estimate slightly slower
		base_time *= 1.15
	
	# Factor in orientation alignment - if we're not facing target, add time for correction
	var facing_direction = projectile.global_transform.basis.z
	var alignment = facing_direction.dot(to_target_normalized)
	
	if alignment < 0.8:
		# Not well aligned, add correction time
		var misalignment_factor = 1.0 + (1.0 - alignment) * 0.5
		base_time *= misalignment_factor
	
	return maxf(base_time, 0.0)


func _update_point_arrow():
	"""Update point_arrow to point toward tank from current camera's perspective.
	Arrow is hidden when camera is looking directly at tank (±10 degrees).
	Arrow rotation indicates direction to turn to face tank."""
	if not point_arrow or not tank:
		if point_arrow:
			point_arrow.visible = false
		return
	
	# Get the current active camera
	var camera = get_viewport().get_camera_3d()
	if not camera:
		point_arrow.visible = false
		return
	
	# Get camera and tank positions
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z  # Camera looks along -Z
	var tank_pos = tank.global_position
	
	# Vector from camera to tank
	var to_tank = (tank_pos - camera_pos).normalized()
	
	# Calculate angle between camera forward and direction to tank
	var dot = camera_forward.dot(to_tank)
	var angle_to_tank_rad = acos(clampf(dot, -1.0, 1.0))
	var angle_to_tank_deg = rad_to_deg(angle_to_tank_rad)
	
	# Hide arrow if looking at tank within ±10 degrees
	const HIDE_THRESHOLD_DEG = 10.0
	if angle_to_tank_deg < HIDE_THRESHOLD_DEG:
		point_arrow.visible = false
		return
	
	# Show arrow and calculate rotation
	point_arrow.visible = true
	
	# Project tank position onto camera's view plane to get 2D direction
	# Get camera's right and up vectors
	var camera_right = camera.global_transform.basis.x
	var camera_up = camera.global_transform.basis.y
	
	# Project to_tank onto the camera's plane (perpendicular to forward)
	# Remove the forward component
	var to_tank_on_plane = to_tank - camera_forward * to_tank.dot(camera_forward)
	to_tank_on_plane = to_tank_on_plane.normalized()
	
	# Get the 2D components (right = X, up = Y in screen space)
	# Note: Negate screen_x because screen coordinates are mirrored
	var screen_x = -to_tank_on_plane.dot(camera_right)  # Negative = invert for correct screen direction
	var screen_y = to_tank_on_plane.dot(camera_up)      # Positive = up
	
	# Calculate rotation angle for the arrow
	# Arrow defaults to pointing UP (0 degrees), so:
	# - If tank is to the right, rotate clockwise (negative angle in Godot 2D)
	# - atan2(x, y) gives angle from Y-axis (up)
	var arrow_angle = atan2(screen_x, screen_y)
	
	# Set arrow rotation (Godot 2D rotation is counterclockwise positive)
	point_arrow.rotation = -arrow_angle

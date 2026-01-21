extends Node

class_name TankMovementController

# ============================================================================
# TANK MOVEMENT CONTROLLER
# ============================================================================
# Moves tank along a path defined by Vector2 (x,z) waypoints.
# Height (Y) and orientation are calculated from HTerrain at each frame.
# Uses smooth rotation interpolation for natural movement.
# ============================================================================

signal movement_started
signal waypoint_reached(waypoint_index: int)
signal movement_stopped
signal movement_completed

var _tank: Node3D = null
var _hterrain: Node3D = null  # Reference to HTerrain node
var _scenario_root: Node = null

# Path data
var _path_positions_2d: PackedVector2Array = PackedVector2Array()
var _path_speeds: Array[float] = []  # km/h
var _initial_delay: float = 0.0

# Movement state
var _current_waypoint_index: int = 0
var _current_speed: float = 0.0  # m/s
var _is_moving: bool = false
var _is_stopped: bool = false  # Permanently stopped (e.g., tank destroyed)
var _delay_timer: float = 0.0
var _delay_finished: bool = false

# Smoothing
var _target_yaw: float = 0.0
var _current_yaw: float = 0.0
@export var rotation_speed: float = 2.0  # rad/s for smooth rotation
@export var debug_enabled: bool = true


func setup(tank: Node3D, scenario_root: Node) -> void:
	"""Initialize the controller with tank node and scene root to find HTerrain."""
	_tank = tank
	_scenario_root = scenario_root
	
	if not _tank:
		push_error("[TankMovementController] Tank node is null")
		return
	
	# Find HTerrain in scene
	_hterrain = _find_hterrain(_scenario_root)
	if _hterrain:
		print("[TankMovementController] Found HTerrain: ", _hterrain.name)
	else:
		push_warning("[TankMovementController] HTerrain not found - using fallback height 0")
	
	# Read path data from tank's meta
	if _tank.has_meta("tank_path_positions_2d"):
		_path_positions_2d = _tank.get_meta("tank_path_positions_2d")
		print("[TankMovementController] Read %d path points from meta" % _path_positions_2d.size())
		for i in range(_path_positions_2d.size()):
			print("  Point %d: (%.1f, %.1f)" % [i, _path_positions_2d[i].x, _path_positions_2d[i].y])
	else:
		push_error("[TankMovementController] NO tank_path_positions_2d meta found!")
	
	if _tank.has_meta("tank_path_speeds"):
		_path_speeds = _tank.get_meta("tank_path_speeds")
		print("[TankMovementController] Read %d path speeds from meta" % _path_speeds.size())
	else:
		push_warning("[TankMovementController] No tank_path_speeds meta, using defaults")
	
	if _tank.has_meta("tank_initial_delay"):
		_initial_delay = _tank.get_meta("tank_initial_delay")
	else:
		push_warning("[TankMovementController] No tank_initial_delay meta, using 0")
	
	# Initialize state
	_current_waypoint_index = 0
	_delay_timer = 0.0
	_delay_finished = _initial_delay <= 0.0
	_is_moving = false
	_is_stopped = false
	
	# Set initial speed (speed after first point = speed[0])
	if _path_speeds.size() > 0:
		_current_speed = _path_speeds[0] / 3.6  # km/h to m/s
	else:
		_current_speed = 25.0 / 3.6  # Default 25 km/h
	
	# Initialize tank position on terrain
	if _path_positions_2d.size() > 0:
		var first_pos_2d = _path_positions_2d[0]
		var terrain_height = _get_terrain_height(first_pos_2d.x, first_pos_2d.y)
		_tank.global_position = Vector3(first_pos_2d.x, terrain_height, first_pos_2d.y)
		print("[TankMovementController] Tank placed at: ", _tank.global_position)
		
		# Initialize yaw towards second waypoint if available
		if _path_positions_2d.size() > 1:
			var next_pos_2d = _path_positions_2d[1]
			var dir = Vector2(next_pos_2d.x - first_pos_2d.x, next_pos_2d.y - first_pos_2d.y)
			# Tank model now faces +Z, so no offset needed
			_current_yaw = atan2(dir.x, dir.y)
			_target_yaw = _current_yaw
			_tank.rotation.y = _current_yaw
			print("[TankMovementController] Initial direction to point 1: (%.1f, %.1f), yaw: %.2f rad" % [dir.x, dir.y, _current_yaw])
	else:
		push_error("[TankMovementController] No path positions to initialize tank!")
	
	_debug_log("Setup complete:")
	_debug_log("  Path points: %d" % _path_positions_2d.size())
	_debug_log("  Initial delay: %.1f s" % _initial_delay)
	_debug_log("  Initial speed: %.1f km/h" % (_current_speed * 3.6))
	if _path_positions_2d.size() > 0:
		_debug_log("  First waypoint: (%.1f, %.1f)" % [_path_positions_2d[0].x, _path_positions_2d[0].y])
		_debug_log("  Tank initial position: %s" % _tank.global_position)


func _find_hterrain(node: Node) -> Node3D:
	"""Recursively find HTerrain node in scene."""
	if node.get_script():
		var script_path = node.get_script().resource_path
		if "hterrain.gd" in script_path:
			return node as Node3D
	
	for child in node.get_children():
		var found = _find_hterrain(child)
		if found:
			return found
	
	return null


func start() -> void:
	"""Start the movement (respecting initial delay)."""
	if _path_positions_2d.size() < 2:
		push_warning("[TankMovementController] Need at least 2 waypoints to move")
		return
	
	_is_moving = true
	movement_started.emit()
	_debug_log("Movement started")


func stop() -> void:
	"""Permanently stop the tank (e.g., when destroyed)."""
	_is_stopped = true
	_is_moving = false
	movement_stopped.emit()
	_debug_log("Movement stopped (tank destroyed)")


func process(delta: float) -> void:
	"""Process tank movement. Call this from _process or _physics_process."""
	if not _tank or _is_stopped:
		return
	
	# Handle initial delay
	if not _delay_finished:
		_delay_timer += delta
		if _delay_timer >= _initial_delay:
			_delay_finished = true
			_debug_log("Initial delay complete, starting movement")
		else:
			# Still waiting - just update terrain alignment
			_align_tank_to_terrain(delta)
			return
	
	if not _is_moving:
		return
	
	# Check if we've reached the end
	if _current_waypoint_index >= _path_positions_2d.size() - 1:
		_is_moving = false
		movement_completed.emit()
		_debug_log("Path completed")
		return
	
	# Get current and target positions in 2D (X, Z plane)
	var current_pos_2d = Vector2(_tank.global_position.x, _tank.global_position.z)
	var target_pos_2d = _path_positions_2d[_current_waypoint_index + 1]
	
	# Calculate direction to target (in XZ plane)
	var direction_2d = target_pos_2d - current_pos_2d
	var distance_to_target = direction_2d.length()
	
	# Check if reached waypoint
	if distance_to_target < 1.0:  # 1m threshold
		_current_waypoint_index += 1
		waypoint_reached.emit(_current_waypoint_index)
		
		# Update speed for next segment
		if _current_waypoint_index < _path_speeds.size():
			var new_speed_kmph = _path_speeds[_current_waypoint_index]
			_current_speed = new_speed_kmph / 3.6
			_debug_log("Waypoint %d reached, new speed: %.1f km/h" % [_current_waypoint_index, new_speed_kmph])
		
		# Check if this was the last waypoint
		if _current_waypoint_index >= _path_positions_2d.size() - 1:
			_is_moving = false
			_current_speed = 0.0
			movement_completed.emit()
			_debug_log("Path completed (all waypoints reached)")
			return
		return
	
	# Move towards target
	if _current_speed > 0.0 and distance_to_target > 0.01:
		var direction_normalized = direction_2d.normalized()
		
		# Calculate yaw to face target (tank model faces +Z, no offset needed)
		_target_yaw = atan2(direction_normalized.x, direction_normalized.y)
		
		# Smooth rotation towards target yaw
		_current_yaw = lerp_angle(_current_yaw, _target_yaw, rotation_speed * delta)
		
		# Move forward based on current facing direction
		# This makes the tank turn while moving, more realistic
		var move_direction = Vector2(sin(_current_yaw), cos(_current_yaw))
		var move_distance = _current_speed * delta
		var new_pos_2d = current_pos_2d + move_direction * move_distance
		
		# Set new XZ position
		_tank.global_position.x = new_pos_2d.x
		_tank.global_position.z = new_pos_2d.y
	
	# Always align to terrain (updates Y position and orientation)
	_align_tank_to_terrain(delta)


func _align_tank_to_terrain(delta: float) -> void:
	"""Align tank to terrain - set Y position and pitch/roll from terrain."""
	if not _tank:
		return
	
	var pos_x = _tank.global_position.x
	var pos_z = _tank.global_position.z
	
	# Get terrain height at current position
	var terrain_height = _get_terrain_height(pos_x, pos_z)
	_tank.global_position.y = terrain_height
	
	# Get terrain normal for orientation
	var terrain_normal = _get_terrain_normal(pos_x, pos_z)
	
	# Apply terrain normal while preserving yaw
	_apply_terrain_orientation(terrain_normal, delta)


func _get_terrain_height(world_x: float, world_z: float) -> float:
	"""Get terrain height at world position using HTerrain."""
	if not _hterrain:
		return 0.0
	
	# Convert world position to terrain map coordinates
	var world_pos = Vector3(world_x, 0, world_z)
	var map_pos = _hterrain.world_to_map(world_pos)
	
	# Get terrain data
	var terrain_data = _hterrain.get_data()
	if not terrain_data:
		return 0.0
	
	# Get raw height from terrain data
	var raw_height = terrain_data.get_interpolated_height_at(map_pos)
	
	# Apply terrain scale
	var map_scale = _hterrain.map_scale
	var scaled_height = raw_height * map_scale.y
	
	# Add terrain's Y offset
	var terrain_origin_y = _hterrain.global_position.y
	
	return scaled_height + terrain_origin_y


func _get_terrain_normal(world_x: float, world_z: float) -> Vector3:
	"""Calculate terrain normal by sampling nearby heights."""
	if not _hterrain:
		return Vector3.UP
	
	# Sample nearby points to calculate normal
	var sample_distance = 0.5  # meters
	var h_center = _get_terrain_height(world_x, world_z)
	var h_right = _get_terrain_height(world_x + sample_distance, world_z)
	var h_forward = _get_terrain_height(world_x, world_z + sample_distance)
	
	# Calculate normal from height differences
	var dx = h_right - h_center
	var dz = h_forward - h_center
	
	var normal = Vector3(-dx / sample_distance, 1.0, -dz / sample_distance).normalized()
	return normal


func _apply_terrain_orientation(terrain_normal: Vector3, delta: float) -> void:
	"""Apply terrain normal to tank orientation while preserving yaw."""
	# Get forward direction from current yaw
	var forward = Vector3(sin(_current_yaw), 0, cos(_current_yaw))
	
	# Calculate right vector
	var right = forward.cross(terrain_normal).normalized()
	if right.length() < 0.01:
		right = Vector3.RIGHT
	
	# Recalculate forward to be perpendicular to both right and terrain normal
	forward = terrain_normal.cross(right).normalized()
	
	# Build new basis
	var target_basis = Basis(right, terrain_normal, -forward)
	
	# Smooth interpolation for orientation (prevents jittery movement)
	var current_basis = _tank.global_transform.basis
	var interpolated_basis = current_basis.slerp(target_basis, rotation_speed * delta)
	
	_tank.global_transform.basis = interpolated_basis


func _debug_log(message: String) -> void:
	"""Print debug message if debug is enabled."""
	if debug_enabled:
		print("[TankMovementController] " + message)


func is_moving() -> bool:
	return _is_moving and not _is_stopped


func is_stopped() -> bool:
	return _is_stopped


func get_current_speed() -> float:
	"""Returns current speed in m/s."""
	return _current_speed if _is_moving and not _is_stopped else 0.0


func get_current_waypoint_index() -> int:
	return _current_waypoint_index

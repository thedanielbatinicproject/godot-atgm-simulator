extends Node

class_name TankMovementController

# ============================================================================
# TANK MOVEMENT CONTROLLER
# ============================================================================
# Moves tank along a path defined by Vector2 (x,z) waypoints.
# Height (Y) and orientation are calculated from terrain at each frame.
# ============================================================================

signal movement_started
signal waypoint_reached(waypoint_index: int)
signal movement_stopped
signal movement_completed

var _tank: Node3D = null
var _space_state: PhysicsDirectSpaceState3D = null

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


func setup(tank: Node3D, space_state: PhysicsDirectSpaceState3D) -> void:
	"""Initialize the controller with tank node and physics space."""
	_tank = tank
	_space_state = space_state
	
	if not _tank:
		push_error("[TankMovementController] Tank node is null")
		return
	
	# Read path data from tank's meta
	if _tank.has_meta("tank_path_positions_2d"):
		_path_positions_2d = _tank.get_meta("tank_path_positions_2d")
	
	if _tank.has_meta("tank_path_speeds"):
		_path_speeds = _tank.get_meta("tank_path_speeds")
	
	if _tank.has_meta("tank_initial_delay"):
		_initial_delay = _tank.get_meta("tank_initial_delay")
	
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
	
	print("[TankMovementController] Setup complete:")
	print("  Path points: %d" % _path_positions_2d.size())
	print("  Initial delay: %.1f s" % _initial_delay)
	print("  Initial speed: %.1f km/h" % (_current_speed * 3.6))


func start() -> void:
	"""Start the movement (respecting initial delay)."""
	if _path_positions_2d.size() < 2:
		push_warning("[TankMovementController] Need at least 2 waypoints to move")
		return
	
	_is_moving = true
	movement_started.emit()


func stop() -> void:
	"""Permanently stop the tank (e.g., when destroyed)."""
	_is_stopped = true
	_is_moving = false
	movement_stopped.emit()


func process(delta: float) -> void:
	"""Process tank movement. Call this from _process or _physics_process."""
	if not _tank or not _space_state or _is_stopped:
		return
	
	# Handle initial delay
	if not _delay_finished:
		_delay_timer += delta
		if _delay_timer >= _initial_delay:
			_delay_finished = true
			print("[TankMovementController] Initial delay complete, starting movement")
		else:
			# Still waiting - just update terrain alignment
			_align_tank_to_terrain()
			return
	
	if not _is_moving:
		return
	
	# Check if we've reached the end
	if _current_waypoint_index >= _path_positions_2d.size() - 1:
		_is_moving = false
		movement_completed.emit()
		return
	
	# Get current and target positions
	var current_pos = _tank.global_position
	var target_pos_2d = _path_positions_2d[_current_waypoint_index + 1]
	var target_pos_3d = Vector3(target_pos_2d.x, current_pos.y, target_pos_2d.y)
	
	# Get terrain height at target position
	var target_terrain = _raycast_terrain(target_pos_3d)
	if target_terrain.hit:
		target_pos_3d.y = target_terrain.position.y
	
	# Calculate direction to target (in XZ plane)
	var direction = target_pos_3d - current_pos
	var distance_to_target = Vector2(direction.x, direction.z).length()
	direction.y = 0
	
	# Check if reached waypoint
	if distance_to_target < 0.5:  # 0.5m threshold
		_current_waypoint_index += 1
		waypoint_reached.emit(_current_waypoint_index)
		
		# Update speed for next segment
		if _current_waypoint_index < _path_speeds.size():
			var new_speed_kmph = _path_speeds[_current_waypoint_index]
			_current_speed = new_speed_kmph / 3.6
			print("[TankMovementController] Waypoint %d reached, new speed: %.1f km/h" % [_current_waypoint_index, new_speed_kmph])
		
		# Check if this was the last waypoint
		if _current_waypoint_index >= _path_positions_2d.size() - 1:
			_is_moving = false
			_current_speed = 0.0
			movement_completed.emit()
			return
		return
	
	# Move towards target
	if _current_speed > 0.0 and direction.length() > 0.01:
		direction = direction.normalized()
		var move_distance = _current_speed * delta
		var new_pos = current_pos + direction * move_distance
		
		# Update Y rotation (yaw) to face movement direction
		var yaw = atan2(direction.x, direction.z)
		_tank.rotation.y = yaw
		
		# Set new XZ position
		_tank.global_position.x = new_pos.x
		_tank.global_position.z = new_pos.z
	
	# Always align to terrain (updates Y position and pitch/roll)
	_align_tank_to_terrain()


func _align_tank_to_terrain() -> void:
	"""Align tank to terrain - set Y position and pitch/roll from terrain normal."""
	if not _tank or not _space_state:
		return
	
	var terrain_result = _raycast_terrain(_tank.global_position)
	if terrain_result.hit:
		# Set Y position to terrain height
		_tank.global_position.y = terrain_result.position.y
		
		# Align to terrain normal while preserving yaw
		_align_to_terrain_normal(terrain_result.normal)


func _raycast_terrain(world_pos: Vector3) -> Dictionary:
	"""Raycast downward to find terrain."""
	var result = {"hit": false, "position": world_pos, "normal": Vector3.UP}
	
	if not _space_state:
		return result
	
	# Use absolute positions high above and below for raycast
	var ray_origin = Vector3(world_pos.x, 1000.0, world_pos.z)
	var ray_end = Vector3(world_pos.x, -1000.0, world_pos.z)
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1  # Layer 1 where terrain collision is
	
	var hit = _space_state.intersect_ray(query)
	if hit:
		result.hit = true
		result.position = hit.position
		result.normal = hit.normal
		# Debug: print terrain hit info
		# print("[TankMovement] Terrain hit at Y=%.2f, normal=%s" % [hit.position.y, hit.normal])
	else:
		push_warning("[TankMovement] No terrain hit at (%.1f, %.1f)" % [world_pos.x, world_pos.z])
	
	return result


func _align_to_terrain_normal(terrain_normal: Vector3) -> void:
	"""Align tank's up vector to terrain normal while preserving yaw."""
	# Current forward direction (preserve yaw)
	var forward = -_tank.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	
	# Calculate right vector
	var right = forward.cross(terrain_normal).normalized()
	
	# Recalculate forward to be perpendicular to both
	forward = terrain_normal.cross(right).normalized()
	
	# Build new basis
	_tank.global_transform.basis = Basis(right, terrain_normal, -forward)


func is_moving() -> bool:
	return _is_moving and not _is_stopped


func is_stopped() -> bool:
	return _is_stopped


func get_current_speed() -> float:
	"""Returns current speed in m/s."""
	return _current_speed if _is_moving and not _is_stopped else 0.0


func get_current_waypoint_index() -> int:
	return _current_waypoint_index

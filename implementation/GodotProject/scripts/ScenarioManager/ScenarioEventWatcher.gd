extends Node

class_name ScenarioEventWatcher

# ============================================================================
# SCENARIO EVENT WATCHER
# ============================================================================
# Monitors projectile, tank, collisions, distance, and scenario conditions.
# Also checks for terrain collision using HTerrain height functions.
# Collision Layers:
#   - Layer 1: Terrain and tank (main game objects)
#   - Layer 2: Other obstacles (buildings, rocks, trees, etc.)
# ============================================================================

signal projectile_hit_tank
signal projectile_hit_ground(position: Vector3)
signal projectile_hit_obstacle(position: Vector3, obstacle: Node)  # Layer 2 collisions
signal projectile_out_of_bounds
signal cutscene_distance_reached
signal terrain_cutscene_distance_reached  # When projectile is close to terrain
signal scenario_timeout
signal player_control_delay_finished

var _projectile: Node3D = null
var _tank: Node3D = null
var _scenario_data: ScenarioData = null
var _scenario_root: Node = null
var _hterrain: Node3D = null  # Reference to HTerrain node

var _scenario_time: float = 0.0
var _control_delay_elapsed: float = 0.0
var _player_control_enabled: bool = false
var _cutscene_triggered: bool = false
var _terrain_hit_triggered: bool = false
var _tank_hit_triggered: bool = false  # Prevent multiple tank hit signals
var _obstacle_hit_triggered: bool = false  # Prevent multiple obstacle hit signals
var _is_watching: bool = false

# Collision layers
const COLLISION_LAYER_TERRAIN: int = 1  # Layer 1: terrain and tank
const COLLISION_LAYER_OBSTACLES: int = 2  # Layer 2: obstacles (buildings, rocks, etc.)

# Proximity-based tank hit detection (backup for physics collision)
@export var tank_hit_radius: float = 5.0  # Meters - radius around tank center for hit detection

# Raycast collision prevention (for high-speed tunneling)
var _last_projectile_position: Vector3 = Vector3.ZERO
var _raycast_initialized: bool = false


func start_watching(scenario_root: Node, scenario_data: ScenarioData) -> void:
	_scenario_data = scenario_data
	_scenario_root = scenario_root
	_scenario_time = 0.0
	_control_delay_elapsed = 0.0
	_player_control_enabled = false
	_cutscene_triggered = false
	_terrain_hit_triggered = false
	_tank_hit_triggered = false
	_obstacle_hit_triggered = false
	_is_watching = true
	
	# Find projectile and tank nodes
	_projectile = scenario_root.get_node_or_null("Projectile")
	_tank = scenario_root.get_node_or_null("Tank")
	
	if _projectile == null:
		push_error("ScenarioEventWatcher: Projectile node not found")
	
	# Find HTerrain node in scene (search recursively)
	_hterrain = _find_hterrain(scenario_root)
	if _hterrain:
		print("[EventWatcher] Found HTerrain: ", _hterrain.name)
	else:
		push_warning("[EventWatcher] HTerrain not found - terrain collision disabled")
	
	# Connect collision signals if available
	_connect_collision_signals()


func _find_hterrain(node: Node) -> Node3D:
	"""Recursively find HTerrain node in scene."""
	# Check if this node is HTerrain (check script name)
	if node.get_script():
		var script_path = node.get_script().resource_path
		if "hterrain.gd" in script_path:
			return node as Node3D
	
	# Check children
	for child in node.get_children():
		var found = _find_hterrain(child)
		if found:
			return found
	
	return null


func _connect_collision_signals() -> void:
	# Try to connect to projectile's collision signal
	if _projectile and _projectile.has_signal("body_entered"):
		if not _projectile.is_connected("body_entered", _on_projectile_collision):
			_projectile.connect("body_entered", _on_projectile_collision)
	
	# Also check for Area3D collision
	var projectile_area = _find_area3d(_projectile)
	if projectile_area and not projectile_area.is_connected("body_entered", _on_projectile_collision):
		projectile_area.connect("body_entered", _on_projectile_collision)


func _find_area3d(node: Node) -> Area3D:
	if node is Area3D:
		return node
	
	for child in node.get_children():
		var found = _find_area3d(child)
		if found:
			return found
	return null


func stop_watching() -> void:
	_is_watching = false
	_projectile = null
	_tank = null
	_scenario_data = null
	_scenario_root = null
	_hterrain = null
	_terrain_hit_triggered = false
	_tank_hit_triggered = false
	_obstacle_hit_triggered = false
	_raycast_initialized = false
	_last_projectile_position = Vector3.ZERO


func process(delta: float) -> void:
	if not _is_watching:
		return
	
	_scenario_time += delta
	
	# Check player control delay
	if not _player_control_enabled:
		_control_delay_elapsed += delta
		if _control_delay_elapsed >= _scenario_data.player_control_delay:
			_player_control_enabled = true
			player_control_delay_finished.emit()
	
	# Check scenario timeout
	if _scenario_time >= _scenario_data.max_scenario_time:
		scenario_timeout.emit()
		return
	
	# Check raycast collision (prevents tunneling at high speeds)
	_check_raycast_collision()
	
	# Check proximity-based tank hit (backup for physics collision)
	_check_tank_proximity_hit()
	
	# Check terrain collision (most important for safety)
	_check_terrain_collision()
	
	# Check distance-based events
	_check_distance_events()
	
	# Check out of bounds
	_check_out_of_bounds()
	
	# Update last position for next frame raycast
	if _projectile:
		_last_projectile_position = _projectile.global_position


func _check_raycast_collision() -> void:
	"""Use raycast to detect collisions between frames (prevents tunneling at high speeds)."""
	if not _projectile or not _scenario_root:
		return
	
	# Skip if any collision already triggered
	if _tank_hit_triggered or _terrain_hit_triggered or _obstacle_hit_triggered:
		return
	
	var current_pos = _projectile.global_position
	
	# Initialize last position on first frame
	if not _raycast_initialized:
		_last_projectile_position = current_pos
		_raycast_initialized = true
		return
	
	# Calculate movement this frame
	var movement = current_pos - _last_projectile_position
	var distance_moved = movement.length()
	
	# Only raycast if we moved a significant distance (high speed detection)
	if distance_moved < 1.0:
		return
	
	# Perform raycast from last position to current position
	# Get world from the projectile (Node3D) instead of scenario_root (Node)
	if not _projectile:
		return
	var world_3d = _projectile.get_world_3d()
	if not world_3d:
		return
	var space_state = world_3d.direct_space_state
	if not space_state:
		return
	
	var query = PhysicsRayQueryParameters3D.create(_last_projectile_position, current_pos)
	# Check collision layers 1 (terrain/tank) and 2 (obstacles)
	query.collision_mask = 0b11  # Layers 1 and 2
	query.collide_with_areas = false  # Don't hit Area3D nodes (triggers, projectile's own area)
	query.collide_with_bodies = true
	
	# Exclude the projectile itself and its children from raycast
	var exclude_rids: Array[RID] = []
	_collect_physics_rids(_projectile, exclude_rids)
	query.exclude = exclude_rids
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_position = result.position
		var hit_body = result.collider
		
		print("[EventWatcher] RAYCAST HIT detected! Object: %s at %s (moved %.1fm this frame)" % [
			hit_body.name if hit_body else "Unknown",
			hit_position,
			distance_moved
		])
		
		# Determine what we hit and emit appropriate signal
		if hit_body == _tank or _is_child_of(_tank, hit_body):
			# Hit the tank!
			_tank_hit_triggered = true
			print("[EventWatcher] TANK HIT (raycast)!")
			projectile_hit_tank.emit()
		elif hit_body is StaticBody3D:
			var static_body := hit_body as StaticBody3D
			var collision_layer = static_body.collision_layer
			
			# Check if it's layer 2 (obstacles)
			if collision_layer & (1 << 1):
				_obstacle_hit_triggered = true
				print("[EventWatcher] OBSTACLE HIT (raycast)!")
				projectile_hit_obstacle.emit(hit_position, hit_body)
			else:
				# Layer 1 or unknown - treat as terrain
				_terrain_hit_triggered = true
				print("[EventWatcher] TERRAIN HIT (raycast)!")
				projectile_hit_ground.emit(hit_position)
		else:
			# Unknown body type - treat as obstacle if in group, otherwise terrain
			if hit_body.is_in_group("obstacles") or hit_body.is_in_group("obstacle"):
				_obstacle_hit_triggered = true
				projectile_hit_obstacle.emit(hit_position, hit_body)
			else:
				_terrain_hit_triggered = true
				projectile_hit_ground.emit(hit_position)


func _collect_physics_rids(node: Node, rids: Array[RID]) -> void:
	"""Recursively collect all physics body RIDs from a node and its children."""
	if node is PhysicsBody3D:
		rids.append(node.get_rid())
	for child in node.get_children():
		_collect_physics_rids(child, rids)


func _check_tank_proximity_hit() -> void:
	"""Check if projectile is close enough to tank to count as a hit (backup for physics)."""
	if not _projectile or not _tank or _tank_hit_triggered or _terrain_hit_triggered:
		return
	
	var distance_to_tank = _projectile.global_position.distance_to(_tank.global_position)
	
	# If projectile is within hit radius of tank, it's a hit!
	if distance_to_tank <= tank_hit_radius:
		_tank_hit_triggered = true
		print("[EventWatcher] TANK HIT (proximity check)! Distance: %.2f m" % distance_to_tank)
		projectile_hit_tank.emit()


func _check_distance_events() -> void:
	if not _projectile or _cutscene_triggered:
		return
	
	# Check distance to tank (if tank exists)
	if _tank:
		var distance_to_tank = _projectile.global_position.distance_to(_tank.global_position)
		
		# Check if we should trigger final cutscene based on tank proximity
		if distance_to_tank <= _scenario_data.final_cutscene_start_distance:
			_cutscene_triggered = true
			cutscene_distance_reached.emit()
			return
	
	# Check distance to terrain using HTerrain
	if _hterrain and not _terrain_hit_triggered:
		var terrain_height = _get_terrain_height_at(_projectile.global_position)
		var distance_to_terrain = _projectile.global_position.y - terrain_height
		
		# Trigger cutscene when close to terrain too
		if distance_to_terrain <= _scenario_data.final_cutscene_start_distance and distance_to_terrain > 0:
			_cutscene_triggered = true
			terrain_cutscene_distance_reached.emit()


func _check_terrain_collision() -> void:
	"""Check if projectile has penetrated terrain surface."""
	if not _projectile or not _hterrain or _terrain_hit_triggered:
		return
	
	var projectile_pos = _projectile.global_position
	var terrain_height = _get_terrain_height_at(projectile_pos)
	
	# Check if projectile is below terrain surface
	if projectile_pos.y <= terrain_height:
		_terrain_hit_triggered = true
		var impact_pos = Vector3(projectile_pos.x, terrain_height, projectile_pos.z)
		print("[EventWatcher] Projectile hit terrain at: ", impact_pos)
		projectile_hit_ground.emit(impact_pos)


func _get_terrain_height_at(world_pos: Vector3) -> float:
	"""Get terrain height at world position, accounting for HTerrain scale and transform."""
	if not _hterrain or not _hterrain.has_method("world_to_map"):
		return -1000.0  # Return very low value if no terrain
	
	# Convert world position to terrain map coordinates
	var map_pos = _hterrain.world_to_map(world_pos)
	
	# Get terrain data
	var terrain_data = _hterrain.get_data() if _hterrain.has_method("get_data") else null
	if not terrain_data:
		return -1000.0
	
	# Get raw height from terrain data (uses map coordinates)
	var raw_height = terrain_data.get_interpolated_height_at(map_pos)
	
	# Apply terrain scale (map_scale.y is the height scale)
	var map_scale = _hterrain.map_scale if "map_scale" in _hterrain else Vector3.ONE
	var scaled_height = raw_height * map_scale.y
	
	# Add terrain's Y offset (from global transform)
	var terrain_origin_y = _hterrain.global_position.y
	
	return scaled_height + terrain_origin_y


func _check_out_of_bounds() -> void:
	if not _projectile or not _scenario_data:
		return
	
	var pos = _projectile.global_position
	
	# Check if projectile is too far from origin (mission area)
	if pos.length() > _scenario_data.mission_area_limit:
		projectile_out_of_bounds.emit()
		return
	
	# Fallback check: if projectile is way below any reasonable terrain level
	if pos.y < -100.0:
		projectile_hit_ground.emit(pos)


func _on_projectile_collision(body: Node) -> void:
	if not _is_watching:
		return
	
	# Check if hit tank (highest priority)
	if body == _tank or _is_child_of(_tank, body):
		if not _tank_hit_triggered:
			_tank_hit_triggered = true
			print("[EventWatcher] TANK HIT (physics collision)!")
			projectile_hit_tank.emit()
		return
	
	# Check for terrain/ground collision (layer 1)
	if body.is_in_group("ground") or body.is_in_group("terrain"):
		if not _terrain_hit_triggered:
			_terrain_hit_triggered = true
			print("[EventWatcher] TERRAIN HIT (group-based)!")
			projectile_hit_ground.emit(_projectile.global_position)
		return
	
	# Check collision layers for static bodies
	if body is StaticBody3D:
		var static_body := body as StaticBody3D
		var collision_layer = static_body.collision_layer
		
		# Layer 2 (bit 1) = obstacles (buildings, rocks, trees, etc.)
		if collision_layer & (1 << 1):  # Check if bit 1 is set (layer 2)
			if not _obstacle_hit_triggered:
				_obstacle_hit_triggered = true
				print("[EventWatcher] OBSTACLE HIT (layer 2)! Object: ", body.name)
				projectile_hit_obstacle.emit(_projectile.global_position, body)
			return
		
		# Layer 1 (bit 0) = terrain (default for StaticBody3D without specific layer)
		if collision_layer & (1 << 0) or collision_layer == 0:  # Layer 1 or no layer set
			if not _terrain_hit_triggered:
				_terrain_hit_triggered = true
				print("[EventWatcher] TERRAIN HIT (layer 1)!")
				projectile_hit_ground.emit(_projectile.global_position)
			return
	
	# Fallback for any other body types - treat as obstacle
	if body.is_in_group("obstacles") or body.is_in_group("obstacle"):
		if not _obstacle_hit_triggered:
			_obstacle_hit_triggered = true
			print("[EventWatcher] OBSTACLE HIT (group-based)! Object: ", body.name)
			projectile_hit_obstacle.emit(_projectile.global_position, body)
		return
	
	# Final fallback: unknown collision, treat as terrain hit
	if not _terrain_hit_triggered and not _obstacle_hit_triggered:
		_terrain_hit_triggered = true
		print("[EventWatcher] UNKNOWN HIT (fallback to terrain)! Object: ", body.name)
		projectile_hit_ground.emit(_projectile.global_position)


func _is_child_of(parent: Node, child: Node) -> bool:
	if parent == null or child == null:
		return false
	
	var current = child.get_parent()
	while current:
		if current == parent:
			return true
		current = current.get_parent()
	
	return false


func get_projectile() -> Node3D:
	return _projectile


func get_tank() -> Node3D:
	return _tank


func get_scenario_time() -> float:
	return _scenario_time


func get_distance_to_tank() -> float:
	if _projectile and _tank:
		return _projectile.global_position.distance_to(_tank.global_position)
	return INF


func is_player_control_enabled() -> bool:
	return _player_control_enabled


func is_cutscene_triggered() -> bool:
	return _cutscene_triggered

extends Node

class_name ScenarioEventWatcher

# ============================================================================
# SCENARIO EVENT WATCHER
# ============================================================================
# Monitors projectile, tank, collisions, distance, and scenario conditions.
# ============================================================================

signal projectile_hit_tank
signal projectile_hit_ground(position: Vector3)
signal projectile_out_of_bounds
signal cutscene_distance_reached
signal scenario_timeout
signal player_control_delay_finished

var _projectile: Node3D = null
var _tank: Node3D = null
var _scenario_data: ScenarioData = null

var _scenario_time: float = 0.0
var _control_delay_elapsed: float = 0.0
var _player_control_enabled: bool = false
var _cutscene_triggered: bool = false
var _is_watching: bool = false


func start_watching(scenario_root: Node, scenario_data: ScenarioData) -> void:
	_scenario_data = scenario_data
	_scenario_time = 0.0
	_control_delay_elapsed = 0.0
	_player_control_enabled = false
	_cutscene_triggered = false
	_is_watching = true
	
	# Find projectile and tank nodes
	_projectile = scenario_root.get_node_or_null("Projectile")
	_tank = scenario_root.get_node_or_null("Tank")
	
	if _projectile == null:
		push_error("ScenarioEventWatcher: Projectile node not found")
	
	# Connect collision signals if available
	_connect_collision_signals()


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
	
	# Check distance-based events
	_check_distance_events()
	
	# Check out of bounds
	_check_out_of_bounds()


func _check_distance_events() -> void:
	if not _projectile or not _tank or _cutscene_triggered:
		return
	
	var distance = _projectile.global_position.distance_to(_tank.global_position)
	
	# Check if we should trigger final cutscene
	if distance <= _scenario_data.final_cutscene_start_distance:
		_cutscene_triggered = true
		cutscene_distance_reached.emit()


func _check_out_of_bounds() -> void:
	if not _projectile or not _scenario_data:
		return
	
	var pos = _projectile.global_position
	
	# Check if projectile is too far from origin (mission area)
	if pos.length() > _scenario_data.mission_area_limit:
		projectile_out_of_bounds.emit()
		return
	
	# Check if projectile is below terrain (simple ground check)
	if pos.y < -10.0:  # Below reasonable terrain level
		projectile_hit_ground.emit(pos)


func _on_projectile_collision(body: Node) -> void:
	if not _is_watching:
		return
	
	# Check if hit tank
	if body == _tank or _is_child_of(_tank, body):
		projectile_hit_tank.emit()
	elif body.is_in_group("ground") or body.is_in_group("terrain"):
		projectile_hit_ground.emit(_projectile.global_position)
	else:
		# Check if it's a static body (likely terrain)
		if body is StaticBody3D:
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

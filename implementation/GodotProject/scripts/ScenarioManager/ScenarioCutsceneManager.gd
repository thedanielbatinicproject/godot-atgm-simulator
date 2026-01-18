extends Node

class_name ScenarioCutsceneManager

# ============================================================================
# SCENARIO CUTSCENE MANAGER
# ============================================================================
# Handles final cutscene when projectile approaches tank:
# - Camera positioned near tank, static (doesn't follow projectile translation)
# - Camera looks at (tracks) the projectile
# - Player input disabled, HUD hidden
# - Physics simulation continues until collision
# - On hit: explosion, tank stops, success screen (camera stays active)
# - On miss (ground hit): explosion, failure screen (camera stays active)
# ============================================================================

signal cutscene_started
signal cutscene_finished
signal hit_animation_started
signal hit_animation_finished
signal miss_animation_started
signal miss_animation_finished
signal tank_should_stop  # Emitted when tank should stop moving

# Camera settings
@export var camera_distance_from_tank: float = 25.0  # How far camera is from tank
@export var camera_height_above_tank: float = 8.0    # How high above tank
@export var camera_side_offset: float = 15.0         # Side offset for better view

# Animation settings
@export var hit_animation_duration: float = 3.5
@export var miss_animation_duration: float = 3.0
@export var projectile_hide_delay: float = 0.5  # Delay before hiding projectile after explosion

var _cutscene_camera: Camera3D = null
var _original_camera: Camera3D = null
var _projectile: Node3D = null
var _tank: Node3D = null
var _is_playing_cutscene: bool = false
var _cutscene_time: float = 0.0
var _camera_position_set: bool = false  # Camera position is set once and stays static
var _explosion_effect: GPUParticles3D = null
var _is_animating: bool = false  # True during hit/miss animation


func start_final_cutscene(projectile: Node3D, tank: Node3D) -> void:
	"""Start the final cutscene - camera near tank, tracking projectile."""
	_projectile = projectile
	_tank = tank
	_is_playing_cutscene = true
	_cutscene_time = 0.0
	_camera_position_set = false
	_is_animating = false
	
	# Store reference to original camera
	_original_camera = get_viewport().get_camera_3d()
	
	# Create and position cutscene camera near tank
	_create_cutscene_camera()
	
	cutscene_started.emit()
	print("[CutsceneManager] Final cutscene started")


func _create_cutscene_camera() -> void:
	"""Create camera positioned near tank, looking at projectile."""
	_cutscene_camera = Camera3D.new()
	_cutscene_camera.name = "FinalCutsceneCamera"
	
	# Add camera to scene
	if _tank:
		_tank.get_parent().add_child(_cutscene_camera)
	elif _projectile:
		_projectile.get_parent().add_child(_cutscene_camera)
	else:
		push_error("[CutsceneManager] No valid parent for camera")
		return
	
	# Calculate static camera position near tank
	_position_camera_near_tank()
	_cutscene_camera.current = true


func _position_camera_near_tank() -> void:
	"""Position camera at a fixed location near the tank with good view of approach."""
	if not _cutscene_camera or not _tank:
		return
	
	var tank_pos = _tank.global_position
	var projectile_pos = _projectile.global_position if _projectile else tank_pos
	
	# Direction from projectile to tank (approach direction)
	var approach_dir = (tank_pos - projectile_pos)
	approach_dir.y = 0
	approach_dir = approach_dir.normalized() if approach_dir.length() > 0.01 else Vector3.FORWARD
	
	# Calculate side vector (perpendicular to approach)
	var side = approach_dir.cross(Vector3.UP).normalized()
	
	# Position camera to the side and behind the tank relative to projectile approach
	# This gives a nice view of the projectile coming toward the tank
	var camera_pos = tank_pos
	camera_pos -= approach_dir * (camera_distance_from_tank * 0.3)  # Slightly behind tank
	camera_pos += side * camera_side_offset                          # To the side
	camera_pos.y += camera_height_above_tank                         # Above
	
	_cutscene_camera.global_position = camera_pos
	_camera_position_set = true
	
	# Initial look at projectile
	if _projectile and is_instance_valid(_projectile):
		_cutscene_camera.look_at(_projectile.global_position)
	else:
		_cutscene_camera.look_at(tank_pos)
	
	print("[CutsceneManager] Camera positioned at: ", camera_pos)


func process_cutscene(delta: float) -> void:
	"""Process cutscene - camera tracks projectile but doesn't move."""
	if not _is_playing_cutscene:
		return
	
	_cutscene_time += delta
	
	# Camera stays in place but tracks the projectile/explosion
	if _cutscene_camera and is_instance_valid(_cutscene_camera):
		var look_target: Vector3
		
		if _projectile and is_instance_valid(_projectile) and _projectile.visible:
			# Track projectile while it's visible
			look_target = _projectile.global_position
		elif _explosion_effect and is_instance_valid(_explosion_effect):
			# Track explosion effect after projectile is hidden
			look_target = _explosion_effect.global_position
		elif _tank and is_instance_valid(_tank):
			# Fallback to tank
			look_target = _tank.global_position
		else:
			return
		
		_cutscene_camera.look_at(look_target)


func play_hit_animation(hit_position: Vector3) -> void:
	"""Play hit animation - explosion at hit position, projectile hides after delay."""
	_is_animating = true
	hit_animation_started.emit()
	
	# Stop the tank
	tank_should_stop.emit()
	
	# Spawn explosion
	_spawn_explosion_effect(hit_position, true)
	
	# Hide projectile after short delay
	await get_tree().create_timer(projectile_hide_delay).timeout
	_hide_projectile()
	
	# Wait for remaining animation duration
	var remaining_time = hit_animation_duration - projectile_hide_delay
	if remaining_time > 0:
		await get_tree().create_timer(remaining_time).timeout
	
	_is_animating = false
	# Emit finished - ScenarioManager will show success screen
	# Camera stays active until end_cutscene() is called
	hit_animation_finished.emit()


func play_miss_animation(impact_position: Vector3) -> void:
	"""Play miss animation - explosion at ground impact, failure."""
	_is_animating = true
	miss_animation_started.emit()
	
	# Spawn ground explosion
	_spawn_explosion_effect(impact_position, false)
	
	# Hide projectile after short delay
	await get_tree().create_timer(projectile_hide_delay).timeout
	_hide_projectile()
	
	# Wait for remaining animation duration
	var remaining_time = miss_animation_duration - projectile_hide_delay
	if remaining_time > 0:
		await get_tree().create_timer(remaining_time).timeout
	
	_is_animating = false
	# Emit finished - ScenarioManager will show failure screen
	# Camera stays active until end_cutscene() is called
	miss_animation_finished.emit()


func _hide_projectile() -> void:
	"""Hide projectile visual representation."""
	if not _projectile or not is_instance_valid(_projectile):
		return
	
	if _projectile.has_method("trigger_explosion"):
		# Use projectile's own method which hides meshes and stops physics
		_projectile.trigger_explosion()
	else:
		# Fallback: hide entire node
		_projectile.visible = false


func _spawn_explosion_effect(position: Vector3, is_hit: bool) -> void:
	"""Create explosion particle effect."""
	_explosion_effect = GPUParticles3D.new()
	_explosion_effect.name = "ExplosionEffect"
	_explosion_effect.global_position = position
	_explosion_effect.emitting = true
	_explosion_effect.one_shot = true
	_explosion_effect.explosiveness = 1.0
	_explosion_effect.amount = 80 if is_hit else 50
	_explosion_effect.lifetime = 2.0
	
	# Create particle material
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 60.0 if is_hit else 45.0
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 20.0 if is_hit else 12.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.8
	material.scale_max = 3.0 if is_hit else 1.5
	
	# Color based on hit or miss
	if is_hit:
		material.color = Color(1.0, 0.6, 0.1)  # Orange/yellow for hit
	else:
		material.color = Color(0.6, 0.5, 0.3)  # Brown/dirt for ground
	
	_explosion_effect.process_material = material
	
	# Add mesh for particles
	var mesh = SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	_explosion_effect.draw_pass_1 = mesh
	
	# Add to scene
	if _tank and is_instance_valid(_tank):
		_tank.get_parent().add_child(_explosion_effect)
	
	# Auto-cleanup after animation completes
	var cleanup_timer = get_tree().create_timer(6.0)
	cleanup_timer.timeout.connect(func():
		if _explosion_effect and is_instance_valid(_explosion_effect):
			_explosion_effect.queue_free()
			_explosion_effect = null
	)
	
	print("[CutsceneManager] Explosion spawned at: ", position, " (hit: ", is_hit, ")")


func end_cutscene() -> void:
	"""Called by ScenarioManager when it's time to fully end the cutscene."""
	_is_playing_cutscene = false
	_is_animating = false
	
	# Restore original camera
	if _original_camera and is_instance_valid(_original_camera):
		_original_camera.current = true
	
	# Remove cutscene camera
	if _cutscene_camera and is_instance_valid(_cutscene_camera):
		_cutscene_camera.queue_free()
		_cutscene_camera = null
	
	cutscene_finished.emit()
	print("[CutsceneManager] Cutscene ended")


func stop_cutscene() -> void:
	"""Force stop the cutscene immediately."""
	if _is_playing_cutscene:
		end_cutscene()


func is_playing_cutscene() -> bool:
	return _is_playing_cutscene


func is_animating() -> bool:
	return _is_animating


func get_cutscene_time() -> float:
	return _cutscene_time


func cleanup() -> void:
	stop_cutscene()
	_projectile = null
	_tank = null
	_original_camera = null
	if _explosion_effect and is_instance_valid(_explosion_effect):
		_explosion_effect.queue_free()
		_explosion_effect = null

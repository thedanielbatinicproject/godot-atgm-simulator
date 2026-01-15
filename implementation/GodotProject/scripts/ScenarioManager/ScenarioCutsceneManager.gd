extends Node

class_name ScenarioCutsceneManager

# ============================================================================
# SCENARIO CUTSCENE MANAGER
# ============================================================================
# Handles final cutscene, hit/miss animations, and camera control.
# ============================================================================

signal cutscene_started
signal cutscene_finished
signal hit_animation_started
signal hit_animation_finished
signal miss_animation_started
signal miss_animation_finished

@export var cutscene_camera_distance: float = 15.0
@export var cutscene_camera_height: float = 5.0
@export var hit_animation_duration: float = 3.0
@export var miss_animation_duration: float = 2.5

var _cutscene_camera: Camera3D = null
var _original_camera: Camera3D = null
var _projectile: Node3D = null
var _tank: Node3D = null
var _is_playing_cutscene: bool = false
var _cutscene_time: float = 0.0


func start_final_cutscene(projectile: Node3D, tank: Node3D) -> void:
	_projectile = projectile
	_tank = tank
	_is_playing_cutscene = true
	_cutscene_time = 0.0
	
	# Store reference to original camera and switch to cutscene camera
	_original_camera = get_viewport().get_camera_3d()
	_create_cutscene_camera()
	
	cutscene_started.emit()


func _create_cutscene_camera() -> void:
	_cutscene_camera = Camera3D.new()
	_cutscene_camera.name = "CutsceneCamera"
	
	# Add camera to scene
	if _projectile:
		_projectile.get_parent().add_child(_cutscene_camera)
	
	# Position camera to view both projectile and tank
	_update_cutscene_camera()
	_cutscene_camera.current = true


func _update_cutscene_camera() -> void:
	if not _cutscene_camera or not _tank:
		return
	
	# Position camera behind and above the projectile, looking at tank
	var target_pos = _tank.global_position
	var projectile_pos = _projectile.global_position if _projectile else target_pos
	
	# Calculate camera position - third person view of the action
	var direction = (target_pos - projectile_pos).normalized()
	var side = direction.cross(Vector3.UP).normalized()
	
	# Camera position: offset to the side and above
	var camera_pos = projectile_pos - direction * cutscene_camera_distance
	camera_pos += side * (cutscene_camera_distance * 0.3)
	camera_pos.y += cutscene_camera_height
	
	_cutscene_camera.global_position = camera_pos
	_cutscene_camera.look_at(lerp(projectile_pos, target_pos, 0.5))


func process_cutscene(delta: float) -> void:
	if not _is_playing_cutscene:
		return
	
	_cutscene_time += delta
	_update_cutscene_camera()


func play_hit_animation(hit_position: Vector3) -> void:
	# Trigger explosion effect on tank
	_spawn_explosion_effect(hit_position, true)
	hit_animation_started.emit()
	
	# Wait for animation duration
	await get_tree().create_timer(hit_animation_duration).timeout
	
	hit_animation_finished.emit()
	_end_cutscene()


func play_miss_animation(impact_position: Vector3) -> void:
	# Trigger ground impact effect
	_spawn_explosion_effect(impact_position, false)
	miss_animation_started.emit()
	
	# Wait for animation duration
	await get_tree().create_timer(miss_animation_duration).timeout
	
	miss_animation_finished.emit()
	_end_cutscene()


func _spawn_explosion_effect(position: Vector3, is_hit: bool) -> void:
	# Create simple particle effect for explosion
	var particles = GPUParticles3D.new()
	particles.name = "ExplosionEffect"
	particles.global_position = position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 50 if is_hit else 30
	
	# Create particle material
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0 if is_hit else 8.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.5
	material.scale_max = 2.0 if is_hit else 1.0
	
	# Color based on hit or miss
	if is_hit:
		material.color = Color(1.0, 0.5, 0.0)  # Orange for hit
	else:
		material.color = Color(0.5, 0.4, 0.3)  # Brown for ground
	
	particles.process_material = material
	
	# Add mesh for particles
	var mesh = SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	particles.draw_pass_1 = mesh
	
	# Add to scene
	if _tank:
		_tank.get_parent().add_child(particles)
	
	# Auto-cleanup after animation
	var cleanup_timer = get_tree().create_timer(5.0)
	cleanup_timer.timeout.connect(func(): particles.queue_free())


func _end_cutscene() -> void:
	_is_playing_cutscene = false
	
	# Restore original camera
	if _original_camera and is_instance_valid(_original_camera):
		_original_camera.current = true
	
	# Remove cutscene camera
	if _cutscene_camera:
		_cutscene_camera.queue_free()
		_cutscene_camera = null
	
	cutscene_finished.emit()


func stop_cutscene() -> void:
	if _is_playing_cutscene:
		_end_cutscene()


func is_playing_cutscene() -> bool:
	return _is_playing_cutscene


func get_cutscene_time() -> float:
	return _cutscene_time


func cleanup() -> void:
	stop_cutscene()
	_projectile = null
	_tank = null
	_original_camera = null

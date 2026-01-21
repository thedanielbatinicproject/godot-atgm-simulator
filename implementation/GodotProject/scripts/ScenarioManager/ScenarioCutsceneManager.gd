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

# Explosion textures
const FIRE_TEXTURE_1 = preload("res://assets/Textures/Explosions/fire_01.png")
const FIRE_TEXTURE_2 = preload("res://assets/Textures/Explosions/fire_02.png")
const SMOKE_TEXTURE_1 = preload("res://assets/Textures/Explosions/smoke_01.png")
const SMOKE_TEXTURE_2 = preload("res://assets/Textures/Explosions/smoke_02.png")

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
var _smoke_effect: GPUParticles3D = null  # Secondary smoke particles
var _is_animating: bool = false  # True during hit/miss animation
var _frozen_camera_position: Vector3 = Vector3.ZERO  # Position where camera freezes
var _pending_smoke_position: Vector3 = Vector3.ZERO  # Position for delayed smoke spawn
var _is_terrain_miss: bool = false  # True if projectile missed tank completely (terrain hit)
var _terrain_impact_position: Vector3 = Vector3.ZERO  # Where projectile hit terrain
var _cutscene_camera_distance: float = 50.0  # Distance from impact for camera positioning


func start_final_cutscene(projectile: Node3D, tank: Node3D, projectile_entry_position: Vector3 = Vector3.ZERO, is_terrain_miss: bool = false, terrain_impact_pos: Vector3 = Vector3.ZERO, camera_distance: float = 50.0) -> void:
	"""Start the final cutscene - camera freezes at projectile's entry point into cutscene sphere.
	For terrain miss: camera locks on impact position instead of tracking tank.
	camera_distance: Distance from impact to position camera (use final_cutscene_start_distance)."""
	_projectile = projectile
	_tank = tank
	_is_playing_cutscene = true
	_cutscene_time = 0.0
	_camera_position_set = false
	_is_animating = false
	_is_terrain_miss = is_terrain_miss
	_terrain_impact_position = terrain_impact_pos
	_cutscene_camera_distance = camera_distance
	
	# Use the entry position if provided, otherwise use current projectile position
	if projectile_entry_position != Vector3.ZERO:
		_frozen_camera_position = projectile_entry_position
	elif _projectile:
		_frozen_camera_position = _projectile.global_position
	else:
		_frozen_camera_position = Vector3.ZERO
	
	# Store reference to original camera
	_original_camera = get_viewport().get_camera_3d()
	
	# Create and position cutscene camera at projectile's entry point
	_create_cutscene_camera()
	
	cutscene_started.emit()
	print("[CutsceneManager] Final cutscene started, camera frozen at: ", _frozen_camera_position)


func _create_cutscene_camera() -> void:
	"""Create camera positioned at the point where projectile entered cutscene radius."""
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
	
	# Position camera at the frozen position (where projectile entered the sphere)
	_position_camera_at_entry_point()
	_cutscene_camera.current = true


func _position_camera_at_entry_point() -> void:
	"""Position camera based on scenario:
	- Tank hit/near miss: Camera positioned to keep tank centered
	- Terrain miss (complete miss): Camera positioned to look at impact point"""
	if not _cutscene_camera:
		return
	
	if _is_terrain_miss and _terrain_impact_position != Vector3.ZERO:
		# TERRAIN MISS: Camera looks at impact position, not tank
		_position_camera_for_terrain_miss()
	else:
		# TANK HIT or near miss: Camera keeps tank centered
		_position_camera_for_tank_centered()


func _position_camera_for_terrain_miss() -> void:
	"""Position camera for terrain/obstacle miss - positioned along projectile path.
	Camera is placed at final_cutscene_start_distance from impact, along the projectile's trajectory."""
	var impact_pos = _terrain_impact_position
	
	# Get approach direction from frozen position (where projectile was) toward impact
	# This is the projectile's flight direction
	var flight_direction = (impact_pos - _frozen_camera_position).normalized()
	if flight_direction.length() < 0.01:
		flight_direction = Vector3(0, 0, -1)  # Default forward
	
	# Position camera along the projectile's path, at cutscene distance BEFORE impact
	# Use + instead of - because frozen_pos might be at/past impact point (raycast detection)
	var camera_distance = maxf(_cutscene_camera_distance, 20.0)  # Minimum 20m for safety
	
	# Camera position: at cutscene distance from impact, OPPOSITE to flight direction
	# This places camera where projectile came from
	var camera_pos = impact_pos + (flight_direction * camera_distance)
	
	# Add slight offset to the side and up for better viewing angle
	var side_direction = flight_direction.cross(Vector3.UP).normalized()
	if side_direction.length() < 0.01:
		side_direction = Vector3.RIGHT
	
	camera_pos += side_direction * (camera_distance * 0.15)  # Small side offset
	camera_pos.y += camera_distance * 0.2  # Slightly above
	
	_cutscene_camera.global_position = camera_pos
	_camera_position_set = true
	
	# Look at impact position (slightly above ground level)
	_cutscene_camera.look_at(impact_pos + Vector3(0, 2, 0))
	
	print("[CutsceneManager] Terrain/obstacle miss camera at: ", camera_pos, " looking at impact: ", impact_pos)


func _position_camera_for_tank_centered() -> void:
	"""Position camera to always keep tank in center of screen.
	Camera is placed at a good viewing angle from the projectile's approach direction.
	If camera would be inside an obstacle (layer 2), rotate around tank until clear."""
	if not _cutscene_camera or not _tank:
		return
	
	var tank_pos = _tank.global_position + Vector3(0, 2, 0)  # Aim at tank center (slightly above ground)
	
	# Direction from tank to projectile entry point (projectile approach direction)
	var approach_direction = (_frozen_camera_position - tank_pos).normalized()
	if approach_direction.length() < 0.01:
		approach_direction = Vector3(0, 0, 1)  # Default forward
	
	# Place camera to the SIDE of the approach path for a dramatic angle
	# This ensures we see both the projectile coming in AND the tank
	var side_direction = approach_direction.cross(Vector3.UP).normalized()
	if side_direction.length() < 0.01:
		side_direction = Vector3.RIGHT
	
	# Camera position: offset from tank, not from entry point
	# This keeps tank centered regardless of where projectile enters
	var camera_distance = 55.0  # Distance from tank (increased for better view)
	var side_offset_amount = 30.0  # How far to the side
	var height_offset = 18.0  # How high above tank
	
	# Calculate initial camera position
	var camera_pos = tank_pos
	camera_pos += approach_direction * (camera_distance * 0.3)  # Slightly toward projectile
	camera_pos += side_direction * side_offset_amount  # To the side
	camera_pos.y += height_offset  # Above
	
	# Check if camera is inside an obstacle (layer 2) and rotate until clear
	camera_pos = _find_clear_camera_position(tank_pos, camera_pos, camera_distance, height_offset)
	
	_cutscene_camera.global_position = camera_pos
	_camera_position_set = true
	
	# ALWAYS look at tank center - this keeps tank in middle of screen
	_cutscene_camera.look_at(tank_pos)
	
	print("[CutsceneManager] Camera at: ", camera_pos, " looking at tank: ", tank_pos)


func _find_clear_camera_position(tank_pos: Vector3, initial_pos: Vector3, _distance: float, height: float) -> Vector3:
	"""Find a camera position that is not inside an obstacle (layer 2).
	Rotates around tank's Y axis until clear position is found."""
	var camera_pos = initial_pos
	
	# Get the world for raycasting
	var world_3d = _tank.get_world_3d() if _tank else null
	if not world_3d:
		return camera_pos
	
	var space_state = world_3d.direct_space_state
	if not space_state:
		return camera_pos
	
	# Check multiple angles around the tank (rotate in 30 degree increments)
	var horizontal_offset = camera_pos - tank_pos
	horizontal_offset.y = 0  # Keep horizontal for rotation
	var original_angle = atan2(horizontal_offset.x, horizontal_offset.z)
	var horizontal_dist = horizontal_offset.length()
	
	for rotation_step in range(12):  # Try 12 positions (30 degrees each = 360)
		var test_angle = original_angle + (rotation_step * PI / 6.0)  # 30 degree increments
		
		# Calculate test position
		var test_pos = tank_pos
		test_pos.x += sin(test_angle) * horizontal_dist
		test_pos.z += cos(test_angle) * horizontal_dist
		test_pos.y = tank_pos.y + height
		
		# Raycast from tank to test position to check for obstacles
		var query = PhysicsRayQueryParameters3D.create(tank_pos, test_pos)
		query.collision_mask = 0b10  # Layer 2 only (obstacles)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		
		if not result:
			# No obstacle hit, this position is clear
			if rotation_step > 0:
				# Add extra rotation for safety (15 degrees more)
				test_angle += PI / 12.0
				test_pos = tank_pos
				test_pos.x += sin(test_angle) * horizontal_dist
				test_pos.z += cos(test_angle) * horizontal_dist
				test_pos.y = tank_pos.y + height
				print("[CutsceneManager] Camera rotated %d degrees to avoid obstacle" % (rotation_step * 30 + 15))
			return test_pos
	
	# All positions blocked, return original
	print("[CutsceneManager] Warning: Could not find clear camera position, using original")
	return camera_pos


func process_cutscene(delta: float) -> void:
	"""Process cutscene - camera behavior depends on hit type.
	Tank hit: Camera tracks tank/projectile.
	Terrain miss: Camera stays locked on impact position."""
	if not _is_playing_cutscene:
		return
	
	_cutscene_time += delta
	
	if not _cutscene_camera or not is_instance_valid(_cutscene_camera):
		return
	
	# TERRAIN MISS: Camera stays locked on impact position
	if _is_terrain_miss and _terrain_impact_position != Vector3.ZERO:
		# Just look at impact point (camera position already set)
		var look_target = _terrain_impact_position + Vector3(0, 2, 0)
		if _explosion_effect and is_instance_valid(_explosion_effect):
			look_target = _explosion_effect.global_position
		_cutscene_camera.look_at(look_target)
		return
	
	# TANK HIT/NEAR MISS: Track weighted point between tank and projectile
	var look_target: Vector3
	
	# Tank is always the primary focus
	var tank_target = _tank.global_position + Vector3(0, 2, 0) if _tank and is_instance_valid(_tank) else Vector3.ZERO
	
	if _projectile and is_instance_valid(_projectile) and _projectile.visible:
		# Track point between projectile and tank - weighted toward tank to keep it centered
		var projectile_pos = _projectile.global_position
		# 70% tank, 30% projectile - this keeps tank mostly centered
		look_target = tank_target.lerp(projectile_pos, 0.3)
	elif _explosion_effect and is_instance_valid(_explosion_effect):
		# During explosion, look at explosion (which should be at/near tank)
		look_target = _explosion_effect.global_position
	elif tank_target != Vector3.ZERO:
		# Fallback to tank
		look_target = tank_target
	else:
		return
	
	_cutscene_camera.look_at(look_target)


func play_hit_animation(hit_position: Vector3) -> void:
	"""Play hit animation - explosion at hit position, tank destruction, projectile hides after delay."""
	_is_animating = true
	hit_animation_started.emit()
	
	# Stop the tank
	tank_should_stop.emit()
	
	# Spawn explosion
	_spawn_explosion_effect(hit_position, true)
	
	# DISMANTLE THE TANK - dramatic destruction!
	if _tank and is_instance_valid(_tank):
		_dismantle_tank(hit_position)
	
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
	print("[CutsceneManager] play_miss_animation called at: ", impact_position)
	
	# Don't start if already animating (hit animation might be playing)
	if _is_animating:
		print("[CutsceneManager] Already animating, skipping miss animation")
		return
	
	_is_animating = true
	miss_animation_started.emit()
	
	# Spawn ground explosion
	_spawn_explosion_effect(impact_position, false)
	
	# Hide projectile IMMEDIATELY for miss (it hit ground)
	_hide_projectile()
	
	# Wait for animation duration
	await get_tree().create_timer(miss_animation_duration).timeout
	
	_is_animating = false
	# Emit finished - ScenarioManager will show failure screen
	# Camera stays active until end_cutscene() is called
	print("[CutsceneManager] miss_animation_finished emitting")
	miss_animation_finished.emit()


func _hide_projectile() -> void:
	"""Hide projectile visual representation."""
	print("[CutsceneManager] _hide_projectile called")
	if not _projectile or not is_instance_valid(_projectile):
		print("[CutsceneManager] No projectile to hide")
		return
	
	if _projectile.has_method("trigger_explosion"):
		# Use projectile's own method which hides meshes and stops physics
		print("[CutsceneManager] Calling projectile.trigger_explosion()")
		_projectile.trigger_explosion()
	else:
		# Fallback: hide entire node
		print("[CutsceneManager] Hiding projectile directly")
		_projectile.visible = false


func _spawn_explosion_effect(position: Vector3, is_hit: bool) -> void:
	"""Create explosion particle effect. Different effects for tank hit vs terrain hit."""
	print("[CutsceneManager] Spawning explosion at: ", position, " is_hit: ", is_hit)
	if is_hit:
		_spawn_tank_explosion(position)
	else:
		_spawn_terrain_explosion(position)


func _create_fire_material(texture: Texture2D) -> StandardMaterial3D:
	"""Create a material for fire particles with the given texture."""
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Emissive/glowing
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = texture
	mat.vertex_color_use_as_albedo = true  # Allow particle color to tint
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	# Disable culling so particles visible from all angles
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _create_smoke_material(texture: Texture2D) -> StandardMaterial3D:
	"""Create a material for smoke particles with the given texture."""
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # Lit smoke
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = texture
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8)  # Slightly grey
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _spawn_delayed_smoke(parent_node: Node) -> void:
	"""Spawn smoke particles 1 second after the initial fire explosion.
	SPAWNS FAST AND THICK - lots of particles quickly!"""
	print("[CutsceneManager] Scheduling delayed smoke spawn...")
	await get_tree().create_timer(1.0).timeout
	
	if not parent_node or not is_instance_valid(parent_node):
		print("[CutsceneManager] Parent node invalid for delayed smoke")
		return
	
	print("[CutsceneManager] Spawning delayed smoke at: ", _pending_smoke_position)
	
	# === SMOKE PARTICLES - FAST & THICK ===
	_smoke_effect = GPUParticles3D.new()
	_smoke_effect.name = "TankSmokeEffect"
	parent_node.add_child(_smoke_effect)
	_smoke_effect.global_position = _pending_smoke_position
	
	_smoke_effect.emitting = true
	_smoke_effect.one_shot = false  # Continuous smoke that lingers!
	_smoke_effect.explosiveness = 0.85  # HIGH explosiveness = spawn quickly!
	_smoke_effect.amount = 200  # LOTS of particles for thick smoke
	_smoke_effect.lifetime = 12.0  # Long lifetime
	_smoke_effect.randomness = 0.3  # Some variation
	_smoke_effect.speed_scale = 1.5  # Faster animation
	
	# Smoke particle behavior - THICK billowing clouds
	var smoke_process = ParticleProcessMaterial.new()
	smoke_process.direction = Vector3(0, 1, 0)
	smoke_process.spread = 85.0  # Wide spread for coverage
	smoke_process.initial_velocity_min = 4.0  # Faster initial burst
	smoke_process.initial_velocity_max = 15.0  # Fast expansion outward
	smoke_process.gravity = Vector3(0, 2.5, 0)  # Rise faster
	smoke_process.scale_min = 35.0  # Large
	smoke_process.scale_max = 90.0  # Very large clouds
	smoke_process.damping_min = 1.0
	smoke_process.damping_max = 2.5
	
	# Emission from sphere - LARGER radius for spread
	smoke_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_process.emission_sphere_radius = 18.0  # Bigger emission area for spread
	
	# Scale curve - start big, grow bigger
	var smoke_scale_curve = CurveTexture.new()
	var smoke_curve = Curve.new()
	smoke_curve.add_point(Vector2(0.0, 0.6))  # Start visible immediately
	smoke_curve.add_point(Vector2(0.1, 0.9))  # Quick growth
	smoke_curve.add_point(Vector2(0.3, 1.0))  # Full size fast
	smoke_curve.add_point(Vector2(0.7, 1.0))  # Stay big
	smoke_curve.add_point(Vector2(1.0, 0.4))  # Fade at end
	smoke_scale_curve.curve = smoke_curve
	smoke_process.scale_curve = smoke_scale_curve
	
	# Turbulence for fluid smoke motion
	smoke_process.turbulence_enabled = true
	smoke_process.turbulence_noise_strength = 5.0
	smoke_process.turbulence_noise_scale = 3.0
	smoke_process.turbulence_noise_speed = Vector3(0.5, 0.8, 0.5)
	
	# Smoke color gradient - THICK AND OPAQUE
	var smoke_gradient = GradientTexture1D.new()
	var smoke_grad = Gradient.new()
	smoke_grad.colors = PackedColorArray([
		Color(0.08, 0.08, 0.08, 0.95),   # Very dark, very opaque
		Color(0.15, 0.15, 0.15, 0.9),    # Dark grey, high opacity
		Color(0.25, 0.25, 0.25, 0.75),   # Medium dark
		Color(0.4, 0.4, 0.4, 0.5),       # Medium grey
		Color(0.55, 0.55, 0.55, 0.0)     # Fading out
	])
	smoke_grad.offsets = PackedFloat32Array([0.0, 0.15, 0.35, 0.65, 1.0])
	smoke_gradient.gradient = smoke_grad
	smoke_process.color_ramp = smoke_gradient
	
	_smoke_effect.process_material = smoke_process
	
	# Smoke mesh with texture - Large for good coverage
	var smoke_mesh = QuadMesh.new()
	smoke_mesh.size = Vector2(14.0, 14.0)  # Good size
	smoke_mesh.material = _create_smoke_material(SMOKE_TEXTURE_1)
	_smoke_effect.draw_pass_1 = smoke_mesh


func _spawn_tank_explosion(position: Vector3) -> void:
	"""Create MASSIVE fiery explosion effect for tank hit with textured particles."""
	print("[CutsceneManager] _spawn_tank_explosion called at: ", position)
	var parent_node = _get_explosion_parent()
	if not parent_node:
		push_error("[CutsceneManager] Cannot spawn tank explosion - no parent node!")
		return
	print("[CutsceneManager] Tank explosion parent: ", parent_node.name)
	
	# === FIRE PARTICLES (main explosion) - MASSIVE VOLUMETRIC FLAMES ===
	_explosion_effect = GPUParticles3D.new()
	_explosion_effect.name = "TankFireEffect"
	parent_node.add_child(_explosion_effect)
	_explosion_effect.global_position = position
	
	_explosion_effect.emitting = true
	_explosion_effect.one_shot = true
	_explosion_effect.explosiveness = 0.7  # Slightly spread out for fluid motion
	_explosion_effect.amount = 200  # MORE particles for volumetric look
	_explosion_effect.lifetime = 3.0  # Longer fire duration
	_explosion_effect.randomness = 0.3  # Add randomness for organic look
	
	# Fire particle behavior - MASSIVE and fluid-like
	var fire_process = ParticleProcessMaterial.new()
	fire_process.direction = Vector3(0, 1, 0)
	fire_process.spread = 60.0  # Tighter cone for rising flames
	fire_process.initial_velocity_min = 8.0
	fire_process.initial_velocity_max = 25.0
	fire_process.gravity = Vector3(0, 6.0, 0)  # Strong upward pull
	fire_process.scale_min = 25.0  # MASSIVE base particles
	fire_process.scale_max = 65.0  # ENORMOUS flames
	fire_process.damping_min = 1.5
	fire_process.damping_max = 4.0
	
	# Scale over lifetime - grow then shrink for fluid billowing
	var scale_curve = CurveTexture.new()
	var scale_c = Curve.new()
	scale_c.add_point(Vector2(0.0, 0.3))   # Start small
	scale_c.add_point(Vector2(0.15, 1.2))  # Grow big quickly (billowing)
	scale_c.add_point(Vector2(0.5, 1.0))   # Stay big
	scale_c.add_point(Vector2(1.0, 0.2))   # Shrink at end
	scale_curve.curve = scale_c
	fire_process.scale_curve = scale_curve
	
	# Add turbulence for fluid motion
	fire_process.turbulence_enabled = true
	fire_process.turbulence_noise_strength = 2.5
	fire_process.turbulence_noise_scale = 1.5
	fire_process.turbulence_noise_speed = Vector3(0.8, 1.2, 0.8)
	
	# Fire color gradient (bright core -> orange flames -> dark edges)
	var fire_gradient = GradientTexture1D.new()
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 0.7, 1.0),   # Bright white-yellow core
		Color(1.0, 0.8, 0.2, 1.0),   # Golden yellow
		Color(1.0, 0.5, 0.0, 0.95),  # Orange
		Color(0.9, 0.25, 0.0, 0.8),  # Red-orange
		Color(0.4, 0.1, 0.0, 0.3),   # Dark red embers
		Color(0.15, 0.05, 0.0, 0.0)  # Fade to black
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.1, 0.3, 0.5, 0.75, 1.0])
	fire_gradient.gradient = gradient
	fire_process.color_ramp = fire_gradient
	
	_explosion_effect.process_material = fire_process
	
	# Fire mesh with texture - MASSIVE base mesh
	var fire_mesh = QuadMesh.new()
	fire_mesh.size = Vector2(6.0, 6.0)  # HUGE base mesh for massive fire
	fire_mesh.material = _create_fire_material(FIRE_TEXTURE_1)
	_explosion_effect.draw_pass_1 = fire_mesh
	
	# === INNER FIRE LAYER (hot core) ===
	var inner_fire = GPUParticles3D.new()
	inner_fire.name = "InnerFireCore"
	parent_node.add_child(inner_fire)
	inner_fire.global_position = position
	
	inner_fire.emitting = true
	inner_fire.one_shot = true
	inner_fire.explosiveness = 0.8
	inner_fire.amount = 80
	inner_fire.lifetime = 2.0
	
	var inner_process = ParticleProcessMaterial.new()
	inner_process.direction = Vector3(0, 1, 0)
	inner_process.spread = 40.0
	inner_process.initial_velocity_min = 5.0
	inner_process.initial_velocity_max = 15.0
	inner_process.gravity = Vector3(0, 8.0, 0)
	inner_process.scale_min = 18.0  # Larger core
	inner_process.scale_max = 40.0  # Much bigger
	inner_process.turbulence_enabled = true
	inner_process.turbulence_noise_strength = 1.5
	
	# Hot white-yellow core gradient
	var core_gradient = GradientTexture1D.new()
	var core_grad = Gradient.new()
	core_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),   # White hot
		Color(1.0, 0.95, 0.6, 1.0),  # Bright yellow
		Color(1.0, 0.7, 0.2, 0.8),   # Golden
		Color(1.0, 0.4, 0.0, 0.0)    # Fade
	])
	core_grad.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 1.0])
	core_gradient.gradient = core_grad
	inner_process.color_ramp = core_gradient
	
	inner_fire.process_material = inner_process
	
	var inner_mesh = QuadMesh.new()
	inner_mesh.size = Vector2(5.0, 5.0)  # LARGER core mesh
	inner_mesh.material = _create_fire_material(FIRE_TEXTURE_2)
	inner_fire.draw_pass_1 = inner_mesh
	
	# === SMOKE PARTICLES - DELAYED by 1 second after fire ===
	# Store position and spawn smoke after delay
	_pending_smoke_position = position
	_spawn_delayed_smoke(parent_node)
	
	# === SECONDARY FIRE BURST (explosive outward blast) ===
	var secondary_fire = GPUParticles3D.new()
	secondary_fire.name = "SecondaryFireBurst"
	parent_node.add_child(secondary_fire)
	secondary_fire.global_position = position + Vector3(0, 1.5, 0)
	
	secondary_fire.emitting = true
	secondary_fire.one_shot = true
	secondary_fire.explosiveness = 0.95
	secondary_fire.amount = 150  # More particles for dense burst
	secondary_fire.lifetime = 2.0
	
	var secondary_process = ParticleProcessMaterial.new()
	secondary_process.direction = Vector3(0, 1, 0)
	secondary_process.spread = 85.0  # Very wide explosive spread
	secondary_process.initial_velocity_min = 15.0
	secondary_process.initial_velocity_max = 45.0
	secondary_process.gravity = Vector3(0, -3.0, 0)  # Slower fall
	secondary_process.scale_min = 18.0  # MASSIVE
	secondary_process.scale_max = 45.0  # ENORMOUS
	
	# Scale animation for fluid bursting
	var burst_scale = CurveTexture.new()
	var burst_curve = Curve.new()
	burst_curve.add_point(Vector2(0.0, 0.5))
	burst_curve.add_point(Vector2(0.2, 1.3))  # Quick expansion
	burst_curve.add_point(Vector2(0.6, 0.8))
	burst_curve.add_point(Vector2(1.0, 0.1))
	burst_scale.curve = burst_curve
	secondary_process.scale_curve = burst_scale
	
	secondary_process.turbulence_enabled = true
	secondary_process.turbulence_noise_strength = 2.0
	
	# Bright initial burst gradient
	var burst_gradient = GradientTexture1D.new()
	var burst_grad = Gradient.new()
	burst_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 0.8, 1.0),
		Color(1.0, 0.7, 0.2, 1.0),
		Color(1.0, 0.3, 0.0, 0.6),
		Color(0.2, 0.1, 0.0, 0.0)
	])
	burst_grad.offsets = PackedFloat32Array([0.0, 0.15, 0.5, 1.0])
	burst_gradient.gradient = burst_grad
	secondary_process.color_ramp = burst_gradient
	
	secondary_fire.process_material = secondary_process
	
	var burst_mesh = QuadMesh.new()
	burst_mesh.size = Vector2(4.0, 4.0)  # Larger burst mesh
	burst_mesh.material = _create_fire_material(FIRE_TEXTURE_2)
	secondary_fire.draw_pass_1 = burst_mesh
	
	_schedule_explosion_cleanup()
	print("[CutsceneManager] MASSIVE tank explosion with fire+smoke spawned at: ", position)


func _spawn_terrain_explosion(position: Vector3) -> void:
	"""Create BIG dirt/dust explosion effect for terrain hit with textured particles."""
	print("[CutsceneManager] _spawn_terrain_explosion called at: ", position)
	var parent_node = _get_explosion_parent()
	if not parent_node:
		push_error("[CutsceneManager] Cannot spawn terrain explosion - no parent node!")
		return
	print("[CutsceneManager] Terrain explosion parent: ", parent_node.name)
	
	# === DIRT/DEBRIS PARTICLES - MORE ===
	_explosion_effect = GPUParticles3D.new()
	_explosion_effect.name = "TerrainDebrisEffect"
	parent_node.add_child(_explosion_effect)
	_explosion_effect.global_position = position
	
	_explosion_effect.emitting = true
	_explosion_effect.one_shot = true
	_explosion_effect.explosiveness = 0.95
	_explosion_effect.amount = 60  # Optimized - fewer but visible
	_explosion_effect.lifetime = 2.5
	
	# Debris particle behavior - thrown upward then falls
	var debris_process = ParticleProcessMaterial.new()
	debris_process.direction = Vector3(0, 1, 0)
	debris_process.spread = 70.0
	debris_process.initial_velocity_min = 8.0
	debris_process.initial_velocity_max = 22.0
	debris_process.gravity = Vector3(0, -15.0, 0)  # Falls back down
	debris_process.scale_min = 1.0  # Bigger chunks
	debris_process.scale_max = 4.0
	debris_process.damping_min = 0.5
	debris_process.damping_max = 2.0
	
	# Dirt color gradient (brown tones)
	var dirt_gradient = GradientTexture1D.new()
	var dirt_grad = Gradient.new()
	dirt_grad.colors = PackedColorArray([
		Color(0.55, 0.4, 0.25, 1.0),  # Light brown
		Color(0.45, 0.35, 0.2, 1.0),  # Medium brown
		Color(0.35, 0.25, 0.15, 0.8), # Dark brown
		Color(0.3, 0.2, 0.1, 0.0)     # Fading
	])
	dirt_grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	dirt_gradient.gradient = dirt_grad
	debris_process.color_ramp = dirt_gradient
	
	_explosion_effect.process_material = debris_process
	
	# Use fire texture tinted brown for debris chunks
	var debris_mesh = QuadMesh.new()
	debris_mesh.size = Vector2(0.8, 0.8)
	var debris_mat = _create_fire_material(FIRE_TEXTURE_2)
	debris_mat.albedo_color = Color(0.6, 0.45, 0.3, 1.0)  # Brown tint
	debris_mesh.material = debris_mat
	_explosion_effect.draw_pass_1 = debris_mesh
	
	# === DUST CLOUD - THICK & OPTIMIZED ===
	_smoke_effect = GPUParticles3D.new()
	_smoke_effect.name = "TerrainDustEffect"
	parent_node.add_child(_smoke_effect)
	_smoke_effect.global_position = position
	
	_smoke_effect.emitting = true
	_smoke_effect.one_shot = false  # Continuous for lingering effect
	_smoke_effect.explosiveness = 0.4
	_smoke_effect.amount = 50  # Fewer but HUGE particles
	_smoke_effect.lifetime = 10.0  # Long lasting dust
	
	# Dust cloud behavior - expands outward and settles
	var dust_process = ParticleProcessMaterial.new()
	dust_process.direction = Vector3(0, 0.3, 0)
	dust_process.spread = 85.0  # Very wide spread
	dust_process.initial_velocity_min = 2.0
	dust_process.initial_velocity_max = 8.0
	dust_process.gravity = Vector3(0, -0.2, 0)  # Very slow settling
	dust_process.scale_min = 12.0  # HUGE particles
	dust_process.scale_max = 35.0  # Massive dust clouds
	dust_process.damping_min = 4.0
	dust_process.damping_max = 8.0
	
	# Dust color gradient - thicker, more opaque
	var dust_gradient = GradientTexture1D.new()
	var dust_grad = Gradient.new()
	dust_grad.colors = PackedColorArray([
		Color(0.55, 0.45, 0.3, 0.85),   # Thick tan dust
		Color(0.5, 0.45, 0.35, 0.65),   # Medium
		Color(0.5, 0.45, 0.4, 0.35),    # Fading
		Color(0.45, 0.42, 0.38, 0.0)    # Gone
	])
	dust_grad.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	dust_gradient.gradient = dust_grad
	dust_process.color_ramp = dust_gradient
	
	_smoke_effect.process_material = dust_process
	
	# Dust mesh - LARGE for thick clouds
	var dust_mesh = QuadMesh.new()
	dust_mesh.size = Vector2(4.0, 4.0)  # Bigger mesh
	var dust_mat = _create_smoke_material(SMOKE_TEXTURE_2)
	dust_mat.albedo_color = Color(0.7, 0.6, 0.5, 0.9)  # Thick tan tint
	dust_mesh.material = dust_mat
	_smoke_effect.draw_pass_1 = dust_mesh
	
	_schedule_explosion_cleanup()
	print("[CutsceneManager] Terrain explosion with debris+dust spawned at: ", position)


func _get_explosion_parent() -> Node:
	"""Get parent node for explosion effect."""
	# Try tank's parent first
	if _tank and is_instance_valid(_tank):
		var parent = _tank.get_parent()
		if parent:
			print("[CutsceneManager] Using tank parent for explosion: ", parent.name)
			return parent
	
	# Try projectile's parent
	if _projectile and is_instance_valid(_projectile):
		var parent = _projectile.get_parent()
		if parent:
			print("[CutsceneManager] Using projectile parent for explosion: ", parent.name)
			return parent
	
	# Fallback: try to get scene root
	var tree = get_tree()
	if tree and tree.current_scene:
		print("[CutsceneManager] Using scene root for explosion")
		return tree.current_scene
	
	push_error("[CutsceneManager] No valid parent for explosion effect")
	return null


func _schedule_explosion_cleanup() -> void:
	"""Schedule automatic cleanup of explosion effects (fire and smoke).
	Smoke persists through success/failure screens for dramatic effect."""
	# Stop smoke emission after 8 seconds (but existing particles continue)
	var stop_emission_timer = get_tree().create_timer(8.0)
	stop_emission_timer.timeout.connect(func():
		if _smoke_effect and is_instance_valid(_smoke_effect):
			_smoke_effect.emitting = false  # Stop new particles, existing ones fade
	)
	
	# Full cleanup after 25 seconds (smoke fully faded by then)
	var cleanup_timer = get_tree().create_timer(25.0)
	cleanup_timer.timeout.connect(func():
		if _explosion_effect and is_instance_valid(_explosion_effect):
			_explosion_effect.queue_free()
			_explosion_effect = null
		if _smoke_effect and is_instance_valid(_smoke_effect):
			_smoke_effect.queue_free()
			_smoke_effect = null
	)


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


# ============================================================================
# TANK DESTRUCTION SYSTEM
# ============================================================================

var _tank_debris: Array[RigidBody3D] = []  # Store references for cleanup


func _get_debris_limit_for_quality() -> int:
	"""Get debris count limit based on graphics quality setting.
	Quality levels from Options menu (item IDs):
	0 = Very High: 40 debris
	1 = High: 35 debris
	2 = Medium: 22 debris
	3 = Low: 16 debris  
	4 = Very Low: 8 debris
	"""
	# Try to get graphics settings from autoload singleton
	var quality = 2  # Default to medium
	if has_node("/root/GraphicsSettingsManager"):
		var gsm = get_node("/root/GraphicsSettingsManager")
		quality = gsm.graphics_settings.get("quality", 2)
		print("[CutsceneManager] Graphics quality from settings: %d" % quality)
	else:
		print("[CutsceneManager] GraphicsSettingsManager not found, using default quality")
	
	# Map quality to debris limit (0=Very High, 4=Very Low)
	match quality:
		0:  # Very High
			return 40
		1:  # High
			return 35
		2:  # Medium
			return 22
		3:  # Low
			return 16
		4:  # Very Low
			return 8
		_:
			return 22  # Default to medium


func _dismantle_tank(explosion_center: Vector3) -> void:
	"""Convert tank MeshInstance3D nodes to physics debris that collapses/explodes.
	Optimized to avoid frame freeze by limiting debris count and using simpler collisions."""
	if not _tank or not is_instance_valid(_tank):
		return
	
	print("[CutsceneManager] Dismantling tank...")
	
	# Hide original tank FIRST (immediate visual feedback)
	_tank.visible = false
	
	# Collect all MeshInstance3D nodes
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(_tank, mesh_instances)
	
	if mesh_instances.is_empty():
		print("[CutsceneManager] No MeshInstance3D found in tank")
		return
	
	print("[CutsceneManager] Found %d mesh instances" % mesh_instances.size())
	
	# Get debris limit based on graphics quality setting
	# Quality: 0=Low, 1=Medium, 2=High (from GraphicsSettingsManager)
	var debris_limit = _get_debris_limit_for_quality()
	var max_debris = mini(mesh_instances.size(), debris_limit)
	print("[CutsceneManager] Debris limit: %d (quality-based)" % max_debris)
	
	# Get parent for debris (scene root)
	var debris_parent = _tank.get_parent()
	if not debris_parent:
		return
	
	# Convert each mesh to physics debris (limited count)
	for i in range(max_debris):
		var mesh_instance = mesh_instances[i]
		if not is_instance_valid(mesh_instance):
			continue
		
		# Skip if mesh is null
		if not mesh_instance.mesh:
			continue
		
		# Create rigid body debris with SIMPLIFIED collision
		var debris = _create_debris_from_mesh_fast(mesh_instance, explosion_center, debris_parent, i)
		if debris:
			_tank_debris.append(debris)
	
	print("[CutsceneManager] Created %d debris pieces" % _tank_debris.size())


func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	"""Recursively collect all MeshInstance3D nodes."""
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	
	for child in node.get_children():
		_collect_mesh_instances(child, result)


func _create_debris_from_mesh(mesh_instance: MeshInstance3D, explosion_center: Vector3, parent: Node, index: int) -> RigidBody3D:
	"""Create a RigidBody3D debris piece from a MeshInstance3D."""
	return _create_debris_from_mesh_fast(mesh_instance, explosion_center, parent, index)


func _create_debris_from_mesh_fast(mesh_instance: MeshInstance3D, explosion_center: Vector3, parent: Node, index: int) -> RigidBody3D:
	"""Create a RigidBody3D debris piece with optimized collision (no convex hull calculation)."""
	# Create rigid body
	var debris = RigidBody3D.new()
	debris.name = "TankDebris_%d" % index
	
	# Copy mesh to new MeshInstance3D
	var debris_mesh = MeshInstance3D.new()
	debris_mesh.mesh = mesh_instance.mesh
	debris_mesh.name = "DebrisMesh"
	
	# Copy materials if any
	for mat_idx in range(mesh_instance.get_surface_override_material_count()):
		var mat = mesh_instance.get_surface_override_material(mat_idx)
		if mat:
			debris_mesh.set_surface_override_material(mat_idx, mat)
	
	# Add mesh to rigid body
	debris.add_child(debris_mesh)
	
	# Create collision shape from mesh (simplified)
	var collision = CollisionShape3D.new()
	collision.name = "DebrisCollision"
	
	# Try to create convex collision shape from mesh
	if mesh_instance.mesh:
		var shape = _create_collision_shape_for_mesh(mesh_instance.mesh)
		if shape:
			collision.shape = shape
			debris.add_child(collision)
	
	# Add to scene
	parent.add_child(debris)
	
	# Position at original mesh's global position
	debris.global_transform = mesh_instance.global_transform
	
	# Calculate explosion force direction
	var debris_pos = debris.global_position
	var direction_from_explosion = (debris_pos - explosion_center).normalized()
	if direction_from_explosion.length() < 0.1:
		# If debris is at explosion center, use random direction
		direction_from_explosion = Vector3(
			randf_range(-1, 1),
			randf_range(0.5, 1),
			randf_range(-1, 1)
		).normalized()
	
	# Add upward bias for dramatic effect
	direction_from_explosion.y = max(direction_from_explosion.y, 0.3)
	direction_from_explosion = direction_from_explosion.normalized()
	
	# Apply explosion impulse
	var distance_to_explosion = debris_pos.distance_to(explosion_center)
	var force_multiplier = clampf(15.0 / max(distance_to_explosion, 1.0), 5.0, 25.0)
	
	var impulse = direction_from_explosion * force_multiplier * randf_range(3.0, 8.0)
	debris.apply_central_impulse(impulse)
	
	# Add random spin for more dramatic effect
	var torque = Vector3(
		randf_range(-5, 5),
		randf_range(-5, 5),
		randf_range(-5, 5)
	)
	debris.apply_torque_impulse(torque)
	
	# Set physics properties
	debris.mass = randf_range(50.0, 300.0)  # Heavy tank parts
	debris.gravity_scale = 1.2  # Slightly heavier fall
	debris.linear_damp = 0.3
	debris.angular_damp = 0.5
	
	# Schedule debris cleanup after some time
	_schedule_debris_freeze(debris, 5.0)
	
	return debris


func _create_collision_shape_for_mesh(mesh: Mesh) -> Shape3D:
	"""Create a simplified collision shape for debris."""
	if not mesh:
		return null
	
	# Try to create convex shape (simpler and faster)
	var aabb = mesh.get_aabb()
	var size = aabb.size
	
	# Use box shape as approximation (faster than convex hull)
	var box = BoxShape3D.new()
	box.size = size * 0.8  # Slightly smaller to avoid sticking
	
	return box


func _schedule_debris_freeze(debris: RigidBody3D, delay: float) -> void:
	"""Freeze debris physics after delay to improve performance."""
	var timer = get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if debris and is_instance_valid(debris):
			debris.freeze = true  # Stop physics simulation
			debris.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	)

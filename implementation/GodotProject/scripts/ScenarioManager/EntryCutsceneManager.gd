extends Node

class_name EntryCutsceneManager

signal cutscene_started
signal cutscene_finished
signal launch_started

var _scenario_root: Node = null
var _scenario_data: ScenarioData = null
var _cutscene_camera: Camera3D = null
var _humvee_instance: Node3D = null
var _launcher_instance: Node3D = null
var _projectile: Node3D = null
var _tank: Node3D = null

var _humvee_audio: AudioStreamPlayer3D = null
var _launch_audio: AudioStreamPlayer3D = null
var _launch_sfx_duration: float = 4.0

var _launch_particles: GPUParticles3D = null

var _camera_shake_time: float = 0.0
var _camera_base_rotation: Vector3 = Vector3.ZERO

var _is_playing: bool = false
var _cutscene_time: float = 0.0
var _cutscene_phase: int = 0
var _phase_timer: float = 0.0

var _launch_root_node: Node3D = null
var _initial_projectile_position: Vector3 = Vector3.ZERO
var _initial_projectile_basis: Basis = Basis.IDENTITY

var _camera_start_rotation: Vector3 = Vector3.ZERO
var _camera_target_rotation: Vector3 = Vector3.ZERO
var _camera_transition_time: float = 0.0
var _camera_transitioning: bool = false

var _launch_in_progress: bool = false
var _launch_time: float = 0.0
var _launch_start_position: Vector3 = Vector3.ZERO
var _launch_direction: Vector3 = Vector3.FORWARD

var _camera_start_fov: float = 60.0
var _camera_target_fov: float = 60.0
var _zooming: bool = false

var _projectile_transition_active: bool = false
var _projectile_transition_time: float = 0.0

enum Phase {
	FADE_IN,
	LOOK_AT_HUMVEE,
	TRANSITION_TO_TANK,
	LOOK_AT_TANK,
	TRANSITION_TO_LAUNCHER,
	WAIT_BEFORE_LAUNCH,
	LAUNCH_SFX,
	TRANSITION_TO_PROJECTILE,
	LAUNCHING,
	TRANSITION_TO_SIMULATION
}

const FADE_IN_DURATION = 0.5
const HUMVEE_LOOK_DURATION = 7.0
const TRANSITION_DURATION = 2.5
const TANK_LOOK_DURATION = 7.0
const WAIT_BEFORE_LAUNCH_DURATION = 6.0
const LAUNCH_SFX_DELAY = 0.5
const PROJECTILE_TRANSITION_DURATION = 0.5

const CAMERA_SHAKE_INTENSITY = 0.012
const CAMERA_SHAKE_SPEED = 0.8

const DEFAULT_FOV = 60.0
const ZOOMED_FOV = 30.0

const TERRAIN_SAMPLE_COUNT = 8
const TERRAIN_SAMPLE_RADIUS = 12.0


func setup(scenario_root: Node, scenario_data: ScenarioData) -> void:
	"""Initialize entry cutscene with scenario data."""
	_scenario_root = scenario_root
	_scenario_data = scenario_data
	_projectile = scenario_root.get_node_or_null("Projectile")
	_tank = scenario_root.get_node_or_null("Tank")
	
	# Get launch sound duration
	var launch_sfx = load("res://assets/Audio/SIM_SFX/launch.wav")
	if launch_sfx:
		_launch_sfx_duration = launch_sfx.get_length()


func start_cutscene() -> void:
	"""Start the entry cutscene sequence."""
	if _is_playing:
		return
	
	_is_playing = true
	_cutscene_time = 0.0
	_cutscene_phase = Phase.LOOK_AT_HUMVEE  # Skip FADE_IN, start directly on humvee
	_phase_timer = 0.0
	_camera_shake_time = 0.0
	
	# Defer spawning to prevent freeze
	call_deferred("_deferred_spawn_props")


func _deferred_spawn_props() -> void:
	"""Spawn props after a frame to avoid freeze."""
	await get_tree().process_frame
	
	_spawn_props()
	_create_cutscene_camera()
	_setup_projectile_at_launcher()
	
	if _projectile:
		_projectile.visible = true
		if _projectile.has_method("disable_physics"):
			_projectile.disable_physics()
	
	cutscene_started.emit()
	print("[EntryCutscene] Started entry cutscene")


func _spawn_props() -> void:
	"""Spawn humvee and launcher near static camera position on flat terrain."""
	if not _scenario_data or not _scenario_root:
		return
	
	var static_cam_pos = _scenario_data.static_camera_location
	var space_state = _get_space_state()
	if not space_state:
		push_warning("[EntryCutscene] Cannot get physics space state")
		return
	
	# Find flat spawn positions using slope preference
	var humvee_pos_xz = _find_flat_spawn_position(static_cam_pos, Vector2(-8, -5), Vector2(-8, 8), space_state)
	var launcher_pos_xz = _find_flat_spawn_position(static_cam_pos, Vector2(5, 8), Vector2(-8, 8), space_state)
	
	# Load scenes dynamically to prevent freeze
	var humvee_scene = load("res://assets/3D Assets/Props/Humvee/humvee.tscn")
	if humvee_scene:
		_humvee_instance = humvee_scene.instantiate()
		_humvee_instance.name = "EntryCutsceneHumvee"
		_scenario_root.add_child(_humvee_instance)
		_place_on_terrain(_humvee_instance, humvee_pos_xz, space_state)
	
	var launcher_scene = load("res://assets/3D Assets/Props/MissleLauncher/launcher_v.tscn")
	if launcher_scene:
		_launcher_instance = launcher_scene.instantiate()
		_launcher_instance.name = "EntryCutsceneLauncher"
		_scenario_root.add_child(_launcher_instance)
		_place_on_terrain(_launcher_instance, launcher_pos_xz, space_state)
	
	_orient_launcher_towards_tank()
	_setup_audio()
	
	print("[EntryCutscene] Spawned props at terrain level")


func _find_flat_spawn_position(center: Vector3, x_range: Vector2, z_range: Vector2, space_state: PhysicsDirectSpaceState3D) -> Vector2:
	"""Sample multiple positions and return the flattest one."""
	var best_pos = Vector2(center.x + randf_range(x_range.x, x_range.y), center.z + randf_range(z_range.x, z_range.y))
	var best_slope = 999.0
	
	for i in range(TERRAIN_SAMPLE_COUNT):
		var sample_x = center.x + randf_range(x_range.x, x_range.y)
		var sample_z = center.z + randf_range(z_range.x, z_range.y)
		var sample_pos = Vector2(sample_x, sample_z)
		
		var slope = _get_terrain_slope(sample_pos, space_state)
		if slope < best_slope:
			best_slope = slope
			best_pos = sample_pos
	
	return best_pos


func _get_terrain_slope(pos_xz: Vector2, space_state: PhysicsDirectSpaceState3D) -> float:
	"""Get terrain slope at position (0 = flat, 1 = vertical)."""
	var ray_origin = Vector3(pos_xz.x, 1000.0, pos_xz.y)
	var ray_end = Vector3(pos_xz.x, -1000.0, pos_xz.y)
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1
	
	var hit = space_state.intersect_ray(query)
	if hit:
		var normal = hit.normal
		return 1.0 - normal.dot(Vector3.UP)
	return 999.0


func _get_space_state() -> PhysicsDirectSpaceState3D:
	"""Get physics space state for raycasting."""
	if _scenario_root:
		for child in _scenario_root.get_children():
			if child is Node3D and child.get_world_3d():
				return child.get_world_3d().direct_space_state
	return null


func _place_on_terrain(node: Node3D, pos_xz: Vector2, space_state: PhysicsDirectSpaceState3D) -> void:
	"""Place a node on terrain at given XZ position with proper height and orientation."""
	var ray_origin = Vector3(pos_xz.x, 1000.0, pos_xz.y)
	var ray_end = Vector3(pos_xz.x, -1000.0, pos_xz.y)
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1
	
	var hit = space_state.intersect_ray(query)
	if hit:
		node.global_position = hit.position
		_align_to_terrain_normal(node, hit.normal)
	else:
		node.global_position = Vector3(pos_xz.x, 0, pos_xz.y)


func _align_to_terrain_normal(node: Node3D, terrain_normal: Vector3) -> void:
	"""Align node's up vector to terrain normal while preserving forward direction."""
	var forward = -node.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	
	var right = forward.cross(terrain_normal).normalized()
	forward = terrain_normal.cross(right).normalized()
	node.global_transform.basis = Basis(right, terrain_normal, -forward)


func _orient_launcher_towards_tank() -> void:
	"""Orient launcher to face tank's initial position (Y rotation only)."""
	if not _launcher_instance or not _scenario_data:
		return
	
	var tank_positions = _scenario_data.tank_path_positions
	if tank_positions.size() == 0:
		return
	
	var tank_start = tank_positions[0]
	var tank_world_pos = Vector3(tank_start.x, 0, tank_start.y)
	var launcher_pos = _launcher_instance.global_position
	
	var direction = (tank_world_pos - launcher_pos).normalized()
	direction.y = 0
	
	if direction.length() > 0.01:
		var current_basis = _launcher_instance.global_transform.basis
		var up = current_basis.y
		var right = Vector3.UP.cross(direction).normalized()
		if right.length() < 0.01:
			right = Vector3.RIGHT
		var new_forward = -direction
		_launcher_instance.global_transform.basis = Basis(right, up, new_forward)


func _setup_projectile_at_launcher() -> void:
	"""Position projectile at launcher's L_ROOT_POS_OR node."""
	if not _launcher_instance or not _projectile:
		return
	
	_launch_root_node = _launcher_instance.get_node_or_null("L_ROOT_POS_OR")
	if not _launch_root_node:
		push_warning("[EntryCutscene] L_ROOT_POS_OR not found in launcher")
		return
	
	_initial_projectile_position = _scenario_data.initial_position
	_initial_projectile_basis = _scenario_data.get_initial_basis()
	
	# Copy position and rotation from L_ROOT_POS_OR
	_projectile.global_transform = _launch_root_node.global_transform
	
	_launch_start_position = _launch_root_node.global_position
	_launch_direction = -_launch_root_node.global_transform.basis.z
	
	print("[EntryCutscene] Projectile positioned at launcher")
	print("[EntryCutscene] L_ROOT_POS_OR rotation: ", _launch_root_node.global_rotation_degrees)
	print("[EntryCutscene] Projectile rotation: ", _projectile.global_rotation_degrees)


func _setup_audio() -> void:
	"""Setup 3D audio players for humvee sounds."""
	if _humvee_instance:
		_humvee_audio = AudioStreamPlayer3D.new()
		var humvee_sfx = load("res://assets/Audio/SIM_SFX/humvee.wav")
		if humvee_sfx:
			_humvee_audio.stream = humvee_sfx
		_humvee_audio.bus = "SFX"
		_humvee_audio.max_distance = 100.0
		_humvee_audio.unit_size = 5.0
		_humvee_instance.add_child(_humvee_audio)
		# Connect finished signal to loop the audio
		_humvee_audio.finished.connect(_on_humvee_audio_finished)
		_humvee_audio.play()


func _create_cutscene_camera() -> void:
	"""Create camera at static camera location."""
	_cutscene_camera = Camera3D.new()
	_cutscene_camera.name = "EntryCutsceneCamera"
	_cutscene_camera.fov = 60.0
	_cutscene_camera.near = 0.1
	_cutscene_camera.far = 10000.0
	
	_cutscene_camera.global_position = _scenario_data.static_camera_location
	_scenario_root.add_child(_cutscene_camera)
	_cutscene_camera.current = true
	
	# Look at humvee with offset to match the LOOK_AT_HUMVEE phase
	if _humvee_instance:
		_cutscene_camera.look_at(_humvee_instance.global_position + Vector3(0, 1, 0), Vector3.UP)


func _on_humvee_audio_finished() -> void:
	"""Restart humvee audio when it finishes to loop indefinitely."""
	if _humvee_audio and is_instance_valid(_humvee_audio) and _is_playing:
		_humvee_audio.play()


func process_cutscene(delta: float) -> void:
	"""Process cutscene animation each frame."""
	if not _is_playing:
		return
	
	_cutscene_time += delta
	_phase_timer += delta
	_camera_shake_time += delta
	
	match _cutscene_phase:
		Phase.FADE_IN:
			if _phase_timer >= FADE_IN_DURATION:
				_advance_phase()
		
		Phase.LOOK_AT_HUMVEE:
			if _humvee_instance and _cutscene_camera:
				_cutscene_camera.look_at(_humvee_instance.global_position + Vector3(0, 1, 0), Vector3.UP)
			if _phase_timer >= HUMVEE_LOOK_DURATION:
				_start_camera_transition_to_tank()
				_advance_phase()
		
		Phase.TRANSITION_TO_TANK:
			_process_camera_transition(delta)
			_process_zoom(delta)
			if _phase_timer >= TRANSITION_DURATION:
				_advance_phase()
		
		Phase.LOOK_AT_TANK:
			if _tank and _cutscene_camera:
				_cutscene_camera.look_at(_tank.global_position + Vector3(0, 2, 0), Vector3.UP)
			if _phase_timer >= TANK_LOOK_DURATION:
				_start_camera_transition_to_launcher()
				_advance_phase()
		
		Phase.TRANSITION_TO_LAUNCHER:
			_process_camera_transition(delta)
			_process_zoom(delta)
			if _phase_timer >= TRANSITION_DURATION:
				_advance_phase()
		
		Phase.WAIT_BEFORE_LAUNCH:
			if _launcher_instance and _cutscene_camera:
				var target = _launch_root_node.global_position if _launch_root_node else _launcher_instance.global_position
				_cutscene_camera.look_at(target + Vector3(0, 1, 0), Vector3.UP)
			if _phase_timer >= WAIT_BEFORE_LAUNCH_DURATION:
				_advance_phase()
		
		Phase.LAUNCH_SFX:
			if _phase_timer >= LAUNCH_SFX_DELAY:
				_play_launch_sound()
				_start_launch()
				_start_camera_transition_to_projectile()
				_advance_phase()
		
		Phase.TRANSITION_TO_PROJECTILE:
			_process_projectile_transition(delta)
			_process_launch(delta)
			if _phase_timer >= PROJECTILE_TRANSITION_DURATION:
				_projectile_transition_active = false
				_advance_phase()
		
		Phase.LAUNCHING:
			_process_launch(delta)
			if _projectile and _cutscene_camera:
				_cutscene_camera.look_at(_projectile.global_position, Vector3.UP)
			if _phase_timer >= _launch_sfx_duration - PROJECTILE_TRANSITION_DURATION:
				_advance_phase()
		
		Phase.TRANSITION_TO_SIMULATION:
			_finish_cutscene()
	
	# Apply camera shake AFTER look_at to make it additive
	_apply_camera_shake()


func _apply_camera_shake() -> void:
	"""Apply subtle human head-like camera shake additively after look_at."""
	if not _cutscene_camera:
		return
	
	# Slow, inert sine-wave based shake (human head bob)
	var shake_x = sin(_camera_shake_time * CAMERA_SHAKE_SPEED * 1.1) * CAMERA_SHAKE_INTENSITY
	var shake_y = sin(_camera_shake_time * CAMERA_SHAKE_SPEED * 0.9 + 1.5) * CAMERA_SHAKE_INTENSITY
	var shake_z = sin(_camera_shake_time * CAMERA_SHAKE_SPEED * 0.7 + 3.0) * CAMERA_SHAKE_INTENSITY * 0.5
	
	# Apply shake additively on top of current rotation
	_cutscene_camera.rotation.x += shake_x
	_cutscene_camera.rotation.y += shake_y
	_cutscene_camera.rotation.z += shake_z


func _advance_phase() -> void:
	"""Move to next cutscene phase."""
	_cutscene_phase += 1
	_phase_timer = 0.0
	print("[EntryCutscene] Phase: %d" % _cutscene_phase)


func _start_camera_transition_to_tank() -> void:
	"""Start camera rotation transition to look at tank with zoom."""
	if not _cutscene_camera or not _tank:
		return
	_camera_start_rotation = _cutscene_camera.global_rotation
	var temp_basis = _cutscene_camera.global_transform.looking_at(_tank.global_position + Vector3(0, 2, 0), Vector3.UP)
	_camera_target_rotation = temp_basis.basis.get_euler()
	_camera_transitioning = true
	_camera_transition_time = 0.0
	# Start zoom in
	_camera_start_fov = _cutscene_camera.fov
	_camera_target_fov = ZOOMED_FOV
	_zooming = true


func _start_camera_transition_to_launcher() -> void:
	"""Start camera rotation transition to look at launcher with unzoom."""
	if not _cutscene_camera or not _launcher_instance:
		return
	_camera_start_rotation = _cutscene_camera.global_rotation
	var target = _launch_root_node.global_position if _launch_root_node else _launcher_instance.global_position
	var temp_basis = _cutscene_camera.global_transform.looking_at(target + Vector3(0, 1, 0), Vector3.UP)
	_camera_target_rotation = temp_basis.basis.get_euler()
	_camera_transitioning = true
	_camera_transition_time = 0.0
	# Start zoom out
	_camera_start_fov = _cutscene_camera.fov
	_camera_target_fov = DEFAULT_FOV
	_zooming = true


func _start_camera_transition_to_projectile() -> void:
	"""Start smooth camera transition to follow projectile."""
	if not _cutscene_camera or not _projectile:
		return
	_camera_start_rotation = _cutscene_camera.global_rotation
	var temp_basis = _cutscene_camera.global_transform.looking_at(_projectile.global_position, Vector3.UP)
	_camera_target_rotation = temp_basis.basis.get_euler()
	_projectile_transition_active = true
	_projectile_transition_time = 0.0


func _process_projectile_transition(delta: float) -> void:
	"""Smoothly interpolate camera to projectile."""
	if not _projectile_transition_active or not _cutscene_camera or not _projectile:
		return
	
	_projectile_transition_time += delta
	var t = clampf(_projectile_transition_time / PROJECTILE_TRANSITION_DURATION, 0.0, 1.0)
	t = _ease_in_out(t)
	
	# Update target rotation as projectile moves
	var current_target = _cutscene_camera.global_transform.looking_at(_projectile.global_position, Vector3.UP)
	_camera_target_rotation = current_target.basis.get_euler()
	
	var new_rotation = _camera_start_rotation.lerp(_camera_target_rotation, t)
	_cutscene_camera.global_rotation = new_rotation


func _process_camera_transition(delta: float) -> void:
	"""Smoothly interpolate camera rotation during transition."""
	if not _camera_transitioning or not _cutscene_camera:
		return
	
	_camera_transition_time += delta
	var t = clampf(_camera_transition_time / TRANSITION_DURATION, 0.0, 1.0)
	t = _ease_in_out(t)
	
	var new_rotation = _camera_start_rotation.lerp(_camera_target_rotation, t)
	_cutscene_camera.global_rotation = new_rotation
	_camera_base_rotation = _cutscene_camera.rotation
	
	if t >= 1.0:
		_camera_transitioning = false


func _process_zoom(_delta: float) -> void:
	"""Process camera FOV zoom during transitions."""
	if not _zooming or not _cutscene_camera:
		return
	
	var t = clampf(_camera_transition_time / TRANSITION_DURATION, 0.0, 1.0)
	t = _ease_in_out(t)
	
	_cutscene_camera.fov = lerpf(_camera_start_fov, _camera_target_fov, t)
	
	if t >= 1.0:
		_zooming = false


func _ease_in_out(t: float) -> float:
	"""Smooth ease in-out interpolation."""
	return t * t * (3.0 - 2.0 * t)


func _play_launch_sound() -> void:
	"""Play launch sound effect attached to projectile with 3D audio and doppler."""
	if not _projectile:
		return
	
	# Create 3D audio player attached to projectile
	_launch_audio = AudioStreamPlayer3D.new()
	var launch_sfx = load("res://assets/Audio/SIM_SFX/launch.wav")
	if launch_sfx:
		_launch_audio.stream = launch_sfx
	_launch_audio.bus = "SFX"
	_launch_audio.max_distance = 4000.0  # 0 volume at 4000m
	_launch_audio.unit_size = 2000.0  # Full volume until 2000m, then starts fading
	_launch_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE  # Linear-like falloff
	_launch_audio.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	_projectile.add_child(_launch_audio)
	_launch_audio.play()
	
	launch_started.emit()


func _start_launch() -> void:
	"""Begin projectile launch animation."""
	_launch_in_progress = true
	_launch_time = 0.0
	
	_create_launch_particles()


func _create_launch_particles() -> void:
	"""Create flame particles at projectile rear using fire texture."""
	if not _projectile:
		return
	
	_launch_particles = GPUParticles3D.new()
	_launch_particles.name = "LaunchFlame"
	_launch_particles.amount = 64
	_launch_particles.lifetime = 0.4
	_launch_particles.speed_scale = 2.0
	_launch_particles.explosiveness = 0.0
	_launch_particles.randomness = 0.2
	_launch_particles.local_coords = true
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.03
	material.direction = Vector3(0, 0, -1)  # Particles go backward from projectile
	material.spread = 15.0
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 18.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.3
	material.scale_max = 0.6
	material.damping_min = 3.0
	material.damping_max = 6.0
	
	# Color modulation over lifetime (brighten then fade)
	var color_ramp = Gradient.new()
	color_ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	color_ramp.add_point(0.3, Color(1.0, 0.9, 0.7, 1.0))
	color_ramp.add_point(0.6, Color(1.0, 0.6, 0.3, 0.8))
	color_ramp.set_color(1, Color(0.5, 0.3, 0.2, 0.0))
	
	var color_texture = GradientTexture1D.new()
	color_texture.gradient = color_ramp
	material.color_ramp = color_texture
	
	# Scale curve - starts small, grows, then fades
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_texture = CurveTexture.new()
	scale_texture.curve = scale_curve
	material.scale_curve = scale_texture
	
	_launch_particles.process_material = material
	
	# Create billboard quad with fire texture
	var quad = QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	
	var quad_mat = StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.vertex_color_use_as_albedo = true
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	# Load fire texture from explosions
	var fire_texture = load("res://assets/Textures/Explosions/fire_01.png")
	if fire_texture:
		quad_mat.albedo_texture = fire_texture
	
	quad.material = quad_mat
	_launch_particles.draw_pass_1 = quad
	
	# Position at projectile rear
	_launch_particles.position = Vector3(0, 0, -0.2)
	_projectile.add_child(_launch_particles)
	_launch_particles.emitting = true
	
	print("[EntryCutscene] Launch particles created with fire texture")


func _process_launch(delta: float) -> void:
	"""Animate projectile leaving launcher and accelerating."""
	if not _launch_in_progress or not _projectile:
		return
	
	_launch_time += delta
	
	var launch_progress = _launch_time / _launch_sfx_duration
	launch_progress = clampf(launch_progress, 0.0, 1.0)
	
	var eased_progress = _ease_in_out(launch_progress)
	
	var current_pos = _launch_start_position.lerp(_initial_projectile_position, eased_progress)
	_projectile.global_position = current_pos
	
	var current_basis = _projectile.global_transform.basis.slerp(_initial_projectile_basis, eased_progress)
	_projectile.global_transform.basis = current_basis


func _finish_cutscene() -> void:
	"""Complete cutscene and transition to simulation."""
	_is_playing = false
	_launch_in_progress = false
	
	# Stop and cleanup particles
	if _launch_particles and is_instance_valid(_launch_particles):
		_launch_particles.emitting = false
	
	if _projectile:
		_projectile.global_position = _initial_projectile_position
		_projectile.global_transform.basis = _initial_projectile_basis
		
		if _projectile.has_method("enable_physics"):
			_projectile.enable_physics()
	
	if _cutscene_camera:
		_cutscene_camera.current = false
	
	print("[EntryCutscene] Cutscene finished, transitioning to simulation")
	cutscene_finished.emit()


func is_playing() -> bool:
	"""Check if cutscene is currently playing."""
	return _is_playing


func cleanup() -> void:
	"""Clean up all cutscene resources."""
	_is_playing = false
	
	if _launch_particles and is_instance_valid(_launch_particles):
		_launch_particles.queue_free()
	if _humvee_instance and is_instance_valid(_humvee_instance):
		_humvee_instance.queue_free()
	if _launcher_instance and is_instance_valid(_launcher_instance):
		_launcher_instance.queue_free()
	if _cutscene_camera and is_instance_valid(_cutscene_camera):
		_cutscene_camera.queue_free()
	
	_launch_particles = null
	_humvee_instance = null
	_launcher_instance = null
	_cutscene_camera = null
	_humvee_audio = null
	_launch_audio = null
	_launch_root_node = null
	_projectile = null
	_tank = null
	_scenario_root = null
	_scenario_data = null

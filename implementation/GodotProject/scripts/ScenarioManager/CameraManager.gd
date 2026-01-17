extends Node

class_name CameraManager

# ============================================================================
# CAMERA MANAGER
# ============================================================================
# Manages switching between projectile camera and static tracking camera.
# Static camera always looks at the projectile.
# ============================================================================

signal camera_switched(camera_name: String)

var _projectile: Node3D = null
var _projectile_camera: Camera3D = null
var _static_camera: Camera3D = null
var _active_camera: Camera3D = null

var _static_camera_position: Vector3 = Vector3.ZERO
var _is_static_active: bool = false


func setup(scenario_root: Node, scenario_data: ScenarioData) -> void:
	"""Initialize cameras for the scenario."""
	_static_camera_position = scenario_data.static_camera_location
	
	# Find projectile and its camera
	_projectile = scenario_root.get_node_or_null("Projectile")
	if _projectile:
		_projectile_camera = _find_camera_in_node(_projectile)
		if _projectile_camera:
			print("[CameraManager] Found projectile camera: ", _projectile_camera.name)
		else:
			push_warning("[CameraManager] No camera found inside Projectile scene!")
	else:
		push_warning("[CameraManager] Projectile node not found!")
	
	# Create static tracking camera
	_create_static_camera(scenario_root)
	
	# Start with projectile camera active
	_is_static_active = false
	_set_active_camera(_projectile_camera)


func _find_camera_in_node(node: Node) -> Camera3D:
	"""Recursively find a Camera3D in the node tree."""
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found = _find_camera_in_node(child)
		if found:
			return found
	return null


func _create_static_camera(scenario_root: Node) -> void:
	"""Create the static camera that tracks the projectile."""
	_static_camera = Camera3D.new()
	_static_camera.name = "StaticTrackingCamera"
	_static_camera.position = _static_camera_position
	_static_camera.current = false
	
	# Set some reasonable camera properties
	_static_camera.fov = 60.0
	_static_camera.near = 0.1
	_static_camera.far = 10000.0
	
	scenario_root.add_child(_static_camera)
	print("[CameraManager] Created static camera at: ", _static_camera_position)


func switch_camera() -> void:
	"""Toggle between projectile camera and static camera."""
	_is_static_active = !_is_static_active
	
	if _is_static_active:
		_set_active_camera(_static_camera)
		camera_switched.emit("Static")
	else:
		_set_active_camera(_projectile_camera)
		camera_switched.emit("Projectile")


func _set_active_camera(camera: Camera3D) -> void:
	"""Set the specified camera as current."""
	if _projectile_camera:
		_projectile_camera.current = false
	if _static_camera:
		_static_camera.current = false
	
	if camera:
		camera.current = true
		_active_camera = camera
		print("[CameraManager] Switched to camera: ", camera.name)
	else:
		push_warning("[CameraManager] Attempted to set null camera as active!")


func process(_delta: float) -> void:
	"""Called every frame to update static camera orientation."""
	if _static_camera and _projectile and _is_static_active:
		# Make static camera look at projectile
		var target_pos = _projectile.global_position
		_static_camera.look_at(target_pos, Vector3.UP)


func set_projectile(projectile: Node3D) -> void:
	"""Update the projectile reference (if spawned later)."""
	_projectile = projectile
	if _projectile:
		_projectile_camera = _find_camera_in_node(_projectile)


func get_active_camera_name() -> String:
	if _active_camera:
		return _active_camera.name
	return "None"


func is_static_camera_active() -> bool:
	return _is_static_active


func cleanup() -> void:
	"""Clean up camera references."""
	if _static_camera and is_instance_valid(_static_camera):
		_static_camera.queue_free()
	_static_camera = null
	_projectile_camera = null
	_projectile = null
	_active_camera = null

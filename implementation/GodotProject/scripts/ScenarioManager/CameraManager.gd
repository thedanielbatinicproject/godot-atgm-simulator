extends Node

class_name CameraManager

# ============================================================================
# CAMERA MANAGER
# ============================================================================
# Manages switching between projectile camera and static tracking camera.
# Supports multiple camera types: OPTICAL, SOUND, IR, THERMAL
# Static camera always looks at the projectile.
# Camera types have different visual effects (shaders).
# ============================================================================

signal camera_switched(camera_name: String)
signal camera_type_changed(camera_type: String)

# Camera types enum
enum CameraType {
	OPTICAL,
	SOUND,
	IR,
	THERMAL
}

# Camera type names for display
const CAMERA_TYPE_NAMES: Dictionary = {
	CameraType.OPTICAL: "OPTICAL",
	CameraType.SOUND: "SOUND",
	CameraType.IR: "IR",
	CameraType.THERMAL: "THERMAL"
}

# Shader paths
const THERMAL_SHADER_PATH = "res://assets/Shaders/thermal_camera.gdshader"
const IR_SHADER_PATH = "res://assets/Shaders/ir_camera.gdshader"
const SOUND_SHADER_PATH = "res://assets/Shaders/sound_camera.gdshader"

var _projectile: Node3D = null
var _projectile_camera: Camera3D = null
var _static_camera: Camera3D = null
var _active_camera: Camera3D = null

var _static_camera_position: Vector3 = Vector3.ZERO
var _is_static_active: bool = false

# Camera type state
var _current_camera_type: CameraType = CameraType.OPTICAL
var _camera_type_order: Array[CameraType] = [CameraType.OPTICAL, CameraType.SOUND, CameraType.IR, CameraType.THERMAL]

# Camera effect overlay
var _effect_overlay: ColorRect = null
var _effect_canvas_layer: CanvasLayer = null  # Separate layer for shader effect (below HUD)
var _shader_materials: Dictionary = {}
var _scenario_root: Node = null


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
	
	# Initialize camera effect shaders
	_setup_camera_effect_shaders()
	
	# Start with projectile camera active
	_is_static_active = false
	_set_active_camera(_projectile_camera)
	
	# Reset to optical camera (no effects)
	_current_camera_type = CameraType.OPTICAL
	_apply_camera_effect()


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


func _setup_camera_effect_shaders() -> void:
	"""Load and setup shader materials for camera effects."""
	# Load shaders
	if ResourceLoader.exists(THERMAL_SHADER_PATH):
		var thermal_shader = load(THERMAL_SHADER_PATH)
		var thermal_mat = ShaderMaterial.new()
		thermal_mat.shader = thermal_shader
		_shader_materials[CameraType.THERMAL] = thermal_mat
		print("[CameraManager] Loaded thermal camera shader")
	else:
		push_warning("[CameraManager] Thermal shader not found: ", THERMAL_SHADER_PATH)
	
	if ResourceLoader.exists(IR_SHADER_PATH):
		var ir_shader = load(IR_SHADER_PATH)
		var ir_mat = ShaderMaterial.new()
		ir_mat.shader = ir_shader
		_shader_materials[CameraType.IR] = ir_mat
		print("[CameraManager] Loaded IR camera shader")
	else:
		push_warning("[CameraManager] IR shader not found: ", IR_SHADER_PATH)
	
	if ResourceLoader.exists(SOUND_SHADER_PATH):
		var sound_shader = load(SOUND_SHADER_PATH)
		var sound_mat = ShaderMaterial.new()
		sound_mat.shader = sound_shader
		_shader_materials[CameraType.SOUND] = sound_mat
		print("[CameraManager] Loaded sound camera shader")
	else:
		push_warning("[CameraManager] Sound shader not found: ", SOUND_SHADER_PATH)


func set_scenario_root(scenario_root: Node) -> void:
	"""Set the scenario root for creating the effect overlay layer."""
	_scenario_root = scenario_root
	_create_effect_overlay()


func _create_effect_overlay() -> void:
	"""Create the full-screen ColorRect for camera effects on a separate layer."""
	if not _scenario_root:
		push_warning("[CameraManager] Cannot create effect overlay: no scenario root set")
		return
	
	if _effect_overlay:
		return  # Already created
	
	# Create a separate CanvasLayer for the effect (below HUD layer which is 10)
	_effect_canvas_layer = CanvasLayer.new()
	_effect_canvas_layer.name = "CameraEffectLayer"
	_effect_canvas_layer.layer = 5  # Below HUD (layer 10) but above 3D view
	_scenario_root.add_child(_effect_canvas_layer)
	
	# Create full-screen ColorRect
	_effect_overlay = ColorRect.new()
	_effect_overlay.name = "CameraEffectOverlay"
	_effect_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effect_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_overlay.visible = false  # Start hidden (OPTICAL mode)
	
	# Add to effect layer (not HUD layer, so HUD is not affected)
	_effect_canvas_layer.add_child(_effect_overlay)
	
	print("[CameraManager] Created camera effect overlay on layer 5 (below HUD)")


func _apply_camera_effect() -> void:
	"""Apply the visual effect for the current camera type."""
	if not _effect_overlay:
		return
	
	if _current_camera_type == CameraType.OPTICAL:
		# No effect for optical camera
		_effect_overlay.visible = false
		_effect_overlay.material = null
		print("[CameraManager] Camera effect: OPTICAL (no shader)")
	else:
		# Apply shader for current camera type
		if _shader_materials.has(_current_camera_type):
			_effect_overlay.material = _shader_materials[_current_camera_type]
			_effect_overlay.visible = true
			print("[CameraManager] Camera effect applied: ", CAMERA_TYPE_NAMES[_current_camera_type])
		else:
			push_warning("[CameraManager] No shader material for camera type: ", CAMERA_TYPE_NAMES[_current_camera_type])
			_effect_overlay.visible = false


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


func cycle_camera_type() -> void:
	"""Cycle to the next camera type (OPTICAL -> SOUND -> IR -> THERMAL -> OPTICAL)."""
	var current_index = _camera_type_order.find(_current_camera_type)
	var next_index = (current_index + 1) % _camera_type_order.size()
	_current_camera_type = _camera_type_order[next_index]
	
	# Apply visual effect for the new camera type
	_apply_camera_effect()
	
	print("[CameraManager] Camera type changed to: ", CAMERA_TYPE_NAMES[_current_camera_type])
	camera_type_changed.emit(CAMERA_TYPE_NAMES[_current_camera_type])


func get_current_camera_type() -> CameraType:
	"""Get current camera type enum value."""
	return _current_camera_type


func get_current_camera_type_name() -> String:
	"""Get current camera type as display string."""
	return CAMERA_TYPE_NAMES[_current_camera_type]


func reset_to_optical() -> void:
	"""Reset camera type to OPTICAL (remove shader effects). Used during cutscenes/end game."""
	if _current_camera_type != CameraType.OPTICAL:
		_current_camera_type = CameraType.OPTICAL
		_apply_camera_effect()
		print("[CameraManager] Camera reset to OPTICAL for cutscene")
		camera_type_changed.emit(CAMERA_TYPE_NAMES[_current_camera_type])


func cleanup() -> void:
	"""Clean up camera references."""
	if _static_camera and is_instance_valid(_static_camera):
		_static_camera.queue_free()
	if _effect_canvas_layer and is_instance_valid(_effect_canvas_layer):
		_effect_canvas_layer.queue_free()  # This also removes _effect_overlay
	_static_camera = null
	_projectile_camera = null
	_projectile = null
	_active_camera = null
	_effect_overlay = null
	_effect_canvas_layer = null
	_scenario_root = null
	_shader_materials.clear()

extends Node

# Singleton for managing and applying graphics settings (quality, AA, etc.)
# Save this as /scripts/MainMenu/Singletons/GraphicsSettingsManager.gd and add as autoload.

var graphics_config_path := "user://settings/graphics.cfg"
var graphics_settings = {
	"quality": 0, # 0=Low, 1=Medium, 2=High
	"aa": 0,      # 0=None, 1=FXAA, 2=TAA, etc.
	"lod_distance": 100.0,
	"texture_quality": 1, # 0=Low, 1=Medium, 2=High
	# Add more as needed
}

func _ready():
	load_graphics_settings()

func load_graphics_settings():
	var config = ConfigFile.new()
	var err = config.load(graphics_config_path)
	if err == OK:
		graphics_settings["quality"] = config.get_value("graphics", "quality", 0)
		graphics_settings["aa"] = config.get_value("graphics", "aa", 0)
		graphics_settings["lod_distance"] = config.get_value("graphics", "lod_distance", 100.0)
		graphics_settings["texture_quality"] = config.get_value("graphics", "texture_quality", 1)
		# Add more as needed
	else:
		save_graphics_settings() # Save defaults if not found

func save_graphics_settings():
	var config = ConfigFile.new()
	config.set_value("graphics", "quality", graphics_settings["quality"])
	config.set_value("graphics", "aa", graphics_settings["aa"])
	config.set_value("graphics", "lod_distance", graphics_settings["lod_distance"])
	config.set_value("graphics", "texture_quality", graphics_settings["texture_quality"])
	# Add more as needed
	config.save(graphics_config_path)

# Call this from scene root to apply settings to all relevant nodes
func apply_graphics_settings_to_scene(scene: Node):
	# Apply AA and quality to all Camera3D nodes
	for camera in scene.get_tree().get_nodes_in_group("cameras"):
		_apply_camera_settings(camera)
	# Apply LOD, texture quality, etc. to other nodes as needed
	# Example: for mesh in scene.get_tree().get_nodes_in_group("lod_meshes"):
	#     mesh.lod_distance = graphics_settings["lod_distance"]

func _apply_camera_settings(camera):
	if not camera:
		return
	# Set AA mode on the Viewport (Godot 4.x)
	var viewport = camera.get_viewport()
	if viewport:
		match graphics_settings["aa"]:
			0:
				viewport.msaa_3d = Viewport.MSAA_DISABLED
			1:
				viewport.msaa_3d = Viewport.MSAA_2X
			2:
				viewport.msaa_3d = Viewport.MSAA_4X
			3:
				viewport.msaa_3d = Viewport.MSAA_8X
			_:
				viewport.msaa_3d = Viewport.MSAA_DISABLED
	# Add more camera/viewport settings as needed

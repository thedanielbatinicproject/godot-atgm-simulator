extends Node
# Attach this script to the root Control or main node of every scene that needs graphics settings applied.
# It will automatically apply graphics settings to all cameras and relevant nodes in the scene.

func _ready():
	# Assumes GraphicsSettingsManager is set as an autoload singleton
	if typeof(GraphicsSettingsManager) != TYPE_NIL:
		GraphicsSettingsManager.apply_graphics_settings_to_scene(get_tree().current_scene)
	else:
		print("[WARNING] GraphicsSettingsManager singleton not found! Graphics settings not applied.")

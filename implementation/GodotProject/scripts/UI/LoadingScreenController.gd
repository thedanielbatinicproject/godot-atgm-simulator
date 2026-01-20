extends Control

## Loading screen controller - hides cursor during loading.

func _ready() -> void:
	# Hide cursor completely during loading
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _exit_tree() -> void:
	# Restore cursor when loading screen is removed
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

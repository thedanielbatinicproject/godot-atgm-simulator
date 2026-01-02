extends Node
class_name BaseInputController

# Signali za event-driven komunikaciju
signal input_enabled(enabled: bool)
signal input_changed(input_value: Vector3)

@export var enabled: bool = true
@export var debug_mode: bool = false

func _ready():
    pass

func enable() -> void:
    enabled = true
    input_enabled.emit(true)
    if debug_mode:
        print("[%s] ENABLED" % name)

func disable() -> void:
    enabled = false
    input_enabled.emit(false)
    if debug_mode:
        print("[%s] DISABLED" % name)

func set_enabled(value: bool) -> void:
    enabled = value
    if enabled:
        enable()
    else:
        disable()

func is_enabled() -> bool:
    return enabled

func get_input_vector() -> Vector3:
    """Override ovdje"""
    return Vector3.ZERO

func reset_input() -> void:
    """Reset input na defaults"""
    pass
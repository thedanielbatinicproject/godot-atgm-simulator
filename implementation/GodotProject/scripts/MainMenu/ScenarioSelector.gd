extends Control

@onready var main_menu_root: VBoxContainer = $"../MainMenuRoot"
@onready var scenario_selector: Control = $"."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_return_btn_pressed() -> void:
	scenario_selector.visible = false
	if main_menu_root:
		main_menu_root.visible = true

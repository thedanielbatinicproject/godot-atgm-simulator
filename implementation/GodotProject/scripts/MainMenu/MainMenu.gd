extends Control

@onready var options: Control = $"Options"
@onready var main_menu: VBoxContainer = $"MainMenuRoot"
@onready var scenario_selector: Control = $ScenarioSelector
@onready var main_menu_music: AudioStreamPlayer = $MainMenuMusic

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_exit_btn_pressed() -> void:
	get_tree().quit()


func _on_option_btn_pressed() -> void:
	main_menu.visible = false
	options.visible = true

func _on_start_btn_pressed() -> void:
	main_menu.visible = false
	scenario_selector.visible = true


func _on_main_menu_music_finished() -> void:
	main_menu_music.play()

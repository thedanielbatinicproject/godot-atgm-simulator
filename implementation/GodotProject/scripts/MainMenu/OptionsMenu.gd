extends Control

@onready var graphics_options_panel: Panel = $SceneRoot/MainContentBox/GRAPHICS
@onready var sound_options_panel: Panel = $SceneRoot/MainContentBox/SOUND
@onready var controls_options_panel: Panel = $SceneRoot/MainContentBox/CONTROLS
@onready var profile_options_panel: Panel = $SceneRoot/MainContentBox/PROFILE

@onready var graphics_settings_btn: Button = $SceneRoot/OptionsMenu/Options/GraphicsSettingsBtn
@onready var sound_settings_btn: Button = $SceneRoot/OptionsMenu/Options/SoundSettingsBtn
@onready var profile_settings_btn: Button = $SceneRoot/OptionsMenu/Options/ProfileSettingsBtn
@onready var controls_settings_btn: Button = $SceneRoot/OptionsMenu/Options/ControlsSettingsBtn

@onready var options: Control = $"."
@onready var main_menu: VBoxContainer = $"../MainMenuRoot"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_active_tab("graphics")

func set_active_tab(tab: String) -> void:
	graphics_options_panel.visible = (tab == "graphics")
	sound_options_panel.visible = (tab == "sound")
	profile_options_panel.visible = (tab == "profile")
	controls_options_panel.visible = (tab == "controls")

	graphics_settings_btn.button_pressed = (tab == "graphics")
	sound_settings_btn.button_pressed = (tab == "sound")
	profile_settings_btn.button_pressed = (tab == "profile")
	controls_settings_btn.button_pressed = (tab == "controls")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_return_btn_pressed() -> void:
	#get_tree().change_scene_to_file("res://scenes/UI/MainMenu/MainMenu.tscn")
	options.visible = false
	main_menu.visible = true



func _on_controls_settings_btn_pressed() -> void:
	set_active_tab("controls")

func _on_profile_settings_btn_pressed() -> void:
	set_active_tab("profile")

func _on_sound_settings_btn_pressed() -> void:
	set_active_tab("sound")

func _on_graphics_settings_btn_pressed() -> void:
	set_active_tab("graphics")


func _on_music_slider_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_ui_slider_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_sfx_slider_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_voice_slider_value_changed(value: float) -> void:
	pass # Replace with function body.

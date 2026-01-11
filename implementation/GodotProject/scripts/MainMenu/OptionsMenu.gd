extends Control

@onready var graphics_options_panel: Panel = $SceneRoot/MainContentBox/GRAPHICS
@onready var sound_options_panel: Panel = $SceneRoot/MainContentBox/SOUND
@onready var controls_options_panel: Panel = $SceneRoot/MainContentBox/CONTROLS
@onready var profile_options_panel: Panel = $SceneRoot/MainContentBox/PROFILE

@onready var graphics_settings_btn: Button = $SceneRoot/OptionsMenu/Options/GraphicsSettingsBtn
@onready var sound_settings_btn: Button = $SceneRoot/OptionsMenu/Options/SoundSettingsBtn
@onready var profile_settings_btn: Button = $SceneRoot/OptionsMenu/Options/ProfileSettingsBtn
@onready var controls_settings_btn: Button = $SceneRoot/OptionsMenu/Options/ControlsSettingsBtn

@onready var main_menu: Control = $"../MainMenuRoot"
@onready var options: Control = $"."

var settings_dir = "user://settings/"
var dir = DirAccess.open(settings_dir)



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_active_tab("graphics")
	if dir == null:
		DirAccess.make_dir_absolute(settings_dir)
	load_display_settings()
	_on_display_apply_btn_pressed() # Apply loaded settings on startup

func set_settings():
	pass

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

#SOUND SETTINGS
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

#DISPLAY SETTINGS
var display_config_path = "user://settings/display.cfg"
var display_settings = {}
func load_display_settings():
	print("[DEBUG] Loading display settings from: ", display_config_path)
	var config = ConfigFile.new()
	var err = config.load(display_config_path)
	if err == OK:
		print("[DEBUG] Config loaded successfully.")
		display_settings["resolution"] = config.get_value("display", "resolution", Vector2i(1920, 1080))
		display_settings["window_mode"] = config.get_value("display", "window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN)
		display_settings["vsync"] = config.get_value("display", "vsync", true)
		print("[DEBUG] Loaded settings: ", display_settings)
	else:
		print("[DEBUG] Config not found or failed to load, using defaults.")
		display_settings["resolution"] = Vector2i(1920, 1080)
		display_settings["window_mode"] = DisplayServer.WINDOW_MODE_FULLSCREEN
		display_settings["vsync"] = true

func _on_resolution_dropdown_item_selected(index: int) -> void:
	var resolutions = [
		Vector2i(1280,1024),
		Vector2i(1920,1080),
		Vector2i(1440,1080),
		Vector2i(2560,1440),
		Vector2i(4096,2160)
	]
	display_settings["resolution"] = resolutions[index]
	save_display_settings()

func save_display_settings():
	print("[DEBUG] Saving display settings to: ", display_config_path)
	var config = ConfigFile.new()
	config.set_value("display", "resolution", display_settings["resolution"])
	config.set_value("display", "window_mode", display_settings["window_mode"])
	config.set_value("display", "vsync", display_settings["vsync"])
	DirAccess.make_dir_absolute(settings_dir) # Ensure directory exists
	var err = config.save(display_config_path)
	if err == OK:
		print("[DEBUG] Config saved successfully.")
	else:
		print("[DEBUG] Failed to save config! Error code: ", err)

func _on_display_apply_btn_pressed() -> void:
	print("[DEBUG] Applying display settings: ", display_settings)
	if display_settings.has("resolution"):
		DisplayServer.window_set_size(display_settings["resolution"])
	if display_settings.has("window_mode"):
		DisplayServer.window_set_mode(display_settings["window_mode"])
	if display_settings.has("vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if display_settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	save_display_settings()

func _on_display_type_dropdown_item_selected(index: int) -> void:
	# 0: Fullscreen, 1: Window, 2: Borderless
	var modes = [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_WINDOWED,
		DisplayServer.WINDOW_FLAG_BORDERLESS
	]
	display_settings["window_mode"] = modes[index]
	save_display_settings()


func _on_vsync_button_toggled(toggled_on: bool) -> void:
	display_settings["vsync"] = toggled_on
	save_display_settings()


#PROFILE SETTINGS

#CONTROLS SETTINGS

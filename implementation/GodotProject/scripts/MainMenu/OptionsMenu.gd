extends Control
@export var enable_debug_logs: bool = false
@onready var graphics_options_panel: Panel = $SceneRoot/MainContentBox/GRAPHICS
@onready var sound_options_panel: Panel = $SceneRoot/MainContentBox/SOUND
@onready var controls_options_panel: Panel = $SceneRoot/MainContentBox/CONTROLS
@onready var profile_options_panel: Panel = $SceneRoot/MainContentBox/PROFILE

@onready var graphics_settings_btn: Button = $SceneRoot/OptionsMenu/Options/GraphicsSettingsBtn
@onready var sound_settings_btn: Button = $SceneRoot/OptionsMenu/Options/SoundSettingsBtn
@onready var profile_settings_btn: Button = $SceneRoot/OptionsMenu/Options/ProfileSettingsBtn
@onready var controls_settings_btn: Button = $SceneRoot/OptionsMenu/Options/ControlsSettingsBtn

# --- SOUND SLIDERS ---
@onready var music_slider: HSlider = $SceneRoot/MainContentBox/SOUND/HBoxContainer/Left/HBoxContainer/BoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MusicSlider
@onready var ui_slider: HSlider = $SceneRoot/MainContentBox/SOUND/HBoxContainer/Left/HBoxContainer/BoxContainer2/MarginContainer/HBoxContainer/BoxContainer2/UISlider
@onready var sfx_slider: HSlider = $SceneRoot/MainContentBox/SOUND/HBoxContainer/LeftRoot2/HBoxContainer/BoxContainer/MarginContainer/HBoxContainer/BoxContainer2/SFXSlider
@onready var voice_slider: HSlider = $SceneRoot/MainContentBox/SOUND/HBoxContainer/LeftRoot2/HBoxContainer/BoxContainer2/MarginContainer/HBoxContainer/BoxContainer2/VoiceSlider

# --- GAME PROFILE ---
@onready var idle_moment_per: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/MarginContainer/HBoxContainer/IdleMomentPer
@onready var thrust_lat: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer2/MarginContainer/HBoxContainer/ThrustLat
@onready var gimbal_lat: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer3/MarginContainer/HBoxContainer/GimbalLat
@onready var vel_alin_coe: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer4/HBoxContainer/VelAlinCoe
@onready var auto_stab: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer2/HBoxContainer/HBoxContainer/AutoStab
@onready var stab_str: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer2/HBoxContainer/HBoxContainer2/StabStr
@onready var roll_max_speed: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer2/HBoxContainer3/HBoxContainer2/RollMaxSpeed
@onready var roll_accel: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer2/HBoxContainer4/HBoxContainer2/RollAccel
@onready var roll_damp: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer2/HBoxContainer2/HBoxContainer2/RollDamp
@onready var description: Label = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/Description
@onready var game_profile: OptionButton = $SceneRoot/MainContentBox/PROFILE/VBoxContainer/VBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/GameProfile

# --- CONTROLS ---
@onready var controls_dropdown: OptionButton = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/ControlsDropdown
@onready var description_controls: Label = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/DescriptionControls
@onready var return_anim_dur: Label = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/MarginContainer/HBoxContainer/ReturnAnimDur
@onready var ret_anim_trans: Label = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer2/MarginContainer/HBoxContainer/RetAnimTrans
@onready var thr_incrm_per_sec: Label = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer3/MarginContainer/HBoxContainer/ThrIncrmPerSec
@onready var throtle_joystick_deadzone: Label = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer4/HBoxContainer/ThrotleJoystickDeadzone
@onready var throtle_cooldown: Label = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer2/HBoxContainer/HBoxContainer/ThrotleCooldown
@onready var joystick_deadzone: Label = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer2/HBoxContainer3/HBoxContainer2/JoystickDeadzone
@onready var enable_keyboard: Label = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer2/HBoxContainer2/HBoxContainer2/EnableKeyboard
@onready var mouse_deadzone: Label = $SceneRoot/MainContentBox/CONTROLS/VBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer2/HBoxContainer4/HBoxContainer2/MouseDeadzone

var return_anim_trans_names = [
	"LINEAR", "SINE", "QUINT", "QUART", "QUAD", "EXPO", "ELASTIC", "CUBIC", "CIRC", "BOUNCE", "BACK", "SPRING"
]
# --- SOUND SETTINGS ---
var sound_config_path = "user://settings/sound.cfg"
var sound_settings = {}

func load_sound_settings():
	if enable_debug_logs:
		print("[DEBUG] Loading sound settings from: ", sound_config_path)
	var config = ConfigFile.new()
	var err = config.load(sound_config_path)
	if err == OK:
		if enable_debug_logs:
			print("[DEBUG] Sound config loaded successfully.")
		sound_settings["music"] = config.get_value("sound", "music", 80.0)
		sound_settings["ui"] = config.get_value("sound", "ui", 80.0)
		sound_settings["sfx"] = config.get_value("sound", "sfx", 80.0)
		sound_settings["voice"] = config.get_value("sound", "voice", 80.0)
		if enable_debug_logs:
			print("[DEBUG] Loaded sound settings: ", sound_settings)
	else:
		if enable_debug_logs:
			print("[DEBUG] Sound config not found or failed to load, using defaults.")
		sound_settings["music"] = 80.0
		sound_settings["ui"] = 80.0
		sound_settings["sfx"] = 80.0
		sound_settings["voice"] = 80.0

func save_sound_settings():
	if enable_debug_logs:
		print("[DEBUG] Saving sound settings to: ", sound_config_path)
	var config = ConfigFile.new()
	config.set_value("sound", "music", sound_settings["music"])
	config.set_value("sound", "ui", sound_settings["ui"])
	config.set_value("sound", "sfx", sound_settings["sfx"])
	config.set_value("sound", "voice", sound_settings["voice"])
	DirAccess.make_dir_absolute(settings_dir)
	var err = config.save(sound_config_path)
	if err == OK and enable_debug_logs:
		print("[DEBUG] Sound config saved successfully.")
	else:
		if enable_debug_logs:
			print("[DEBUG] Failed to save sound config! Error code: ", err)

func set_sound_menu_options():
	music_slider.value = sound_settings.get("music", 100.0)
	ui_slider.value = sound_settings.get("ui", 100.0)
	sfx_slider.value = sound_settings.get("sfx", 100.0)
	voice_slider.value = sound_settings.get("voice", 100.0)

func _on_music_slider_value_changed(value: float) -> void:
	sound_settings["music"] = value
	save_sound_settings()

func _on_ui_slider_value_changed(value: float) -> void:
	sound_settings["ui"] = value
	save_sound_settings()

func _on_sfx_slider_value_changed(value: float) -> void:
	sound_settings["sfx"] = value
	save_sound_settings()

func _on_voice_slider_value_changed(value: float) -> void:
	sound_settings["voice"] = value
	save_sound_settings()


@onready var main_menu: Control = $"../MainMenuRoot"
@onready var options: Control = $"."

var settings_dir := "user://settings/"
var dir = DirAccess.open(settings_dir)

@onready var resolution_dropdown: OptionButton = $SceneRoot/MainContentBox/GRAPHICS/HBoxContainer/LeftRoot/VBoxContainer/BoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/ResolutionDropdown
@onready var display_type_dropdown: OptionButton = $SceneRoot/MainContentBox/GRAPHICS/HBoxContainer/LeftRoot/VBoxContainer/BoxContainer3/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/DisplayTypeDropdown
@onready var vsync_button: CheckButton = $SceneRoot/MainContentBox/GRAPHICS/HBoxContainer/LeftRoot/VBoxContainer/BoxContainer2/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VsyncButton
@onready var brightness_slider: HSlider = $SceneRoot/MainContentBox/GRAPHICS/HBoxContainer/RightRoot/VBoxContainer/BoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/BrightnessSlider
@onready var aa_dropdown: OptionButton = $SceneRoot/MainContentBox/GRAPHICS/HBoxContainer/RightRoot/VBoxContainer/BoxContainer2/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/AADropdown
@onready var graphics_quality_dropdown: OptionButton = $SceneRoot/MainContentBox/GRAPHICS/HBoxContainer/RightRoot/VBoxContainer/BoxContainer3/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/GraphicsQualityDropdown

var resolutions = [
	Vector2i(1280,1024),
	Vector2i(1920,1080),
	Vector2i(1440,1080),
	Vector2i(2560,1440),
	Vector2i(4096,2160)
]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	DirAccess.make_dir_absolute(settings_dir)
	load_profile_settings()
	load_game_profiles()
	set_game_profile_menu_options()
	load_controls_settings()
	load_controls_configs()
	set_controls_menu_options()
	set_active_tab("graphics")
	load_display_settings()
	load_sound_settings()
	set_menu_options()
	set_sound_menu_options()
	_on_apply_btn_pressed()

func set_menu_options():
	# --- GRAPHICS OPTIONS ---
	# Set resolution dropdown
	var res_idx = resolutions.find(display_settings.get("resolution", Vector2i(1920,1080)))
	if res_idx != -1:
		resolution_dropdown.select(res_idx)

	# Set display type dropdown
	# 0: Fullscreen, 1: Window, 2: Borderless
	var mode_idx = 0
	if display_settings.get("window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN) == DisplayServer.WINDOW_MODE_FULLSCREEN:
		mode_idx = 0
	elif display_settings.get("window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN) == DisplayServer.WINDOW_MODE_WINDOWED and display_settings.get("borderless", false) == false:
		mode_idx = 1
	elif display_settings.get("window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN) == DisplayServer.WINDOW_MODE_WINDOWED and display_settings.get("borderless", false) == true:
		mode_idx = 2
	display_type_dropdown.select(mode_idx)

	vsync_button.button_pressed = display_settings.get("vsync", true)

	brightness_slider.value = display_settings.get("brightness", 1.0)

	graphics_quality_dropdown.select(display_settings.get("graphics_quality", 0))

	aa_dropdown.select(display_settings.get("aa", 0))

	# --- SOUND OPTIONS ---
	set_sound_menu_options()
	# --- GAME PROFILE OPTIONS ---
	set_game_profile_menu_options()
	# --- CONTROLS OPTIONS ---
	set_controls_menu_options()
	# --- PROFILE/CONTROLS OPTIONS ---
	# Add similar logic for other option categories as needed

func set_active_tab(tab: String) -> void:
	graphics_options_panel.visible = (tab == "graphics")
	sound_options_panel.visible = (tab == "sound")
	profile_options_panel.visible = (tab == "profile")
	controls_options_panel.visible = (tab == "controls")

	graphics_settings_btn.button_pressed = (tab == "graphics")
	sound_settings_btn.button_pressed = (tab == "sound")
	profile_settings_btn.button_pressed = (tab == "profile")
	controls_settings_btn.button_pressed = (tab == "controls")

	# Always update game profile and controls menu to reflect saved config when switching tabs
	if tab == "profile":
		load_profile_settings()
		set_game_profile_menu_options()
	if tab == "controls":
		load_controls_settings()
		set_controls_menu_options()

func _on_return_btn_pressed() -> void:
	load_profile_settings()
	set_game_profile_menu_options()
	load_controls_settings()
	set_controls_menu_options()
	options.visible = false
	main_menu.visible = true
func _on_apply_btn_pressed() -> void:
	save_profile_settings()
	save_controls_settings()
	apply_display_settings()


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
	if enable_debug_logs:
		print("[DEBUG] Loading display settings from: ", display_config_path)
	var config = ConfigFile.new()
	var err = config.load(display_config_path)
	if err == OK:
		if enable_debug_logs:
			print("[DEBUG] Config loaded successfully.")
		display_settings["resolution"] = config.get_value("display", "resolution", Vector2i(1920, 1080))
		display_settings["window_mode"] = config.get_value("display", "window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN)
		display_settings["borderless"] = config.get_value("display", "borderless", false)
		display_settings["vsync"] = config.get_value("display", "vsync", true)
		display_settings["brightness"] = config.get_value("display", "brightness", 1.0)
		display_settings["graphics_quality"] = config.get_value("display", "graphics_quality", 0)
		display_settings["aa"] = config.get_value("display", "aa", 0)
		if enable_debug_logs:
			print("[DEBUG] Loaded settings: ", display_settings)
	else:
		if enable_debug_logs:
			print("[DEBUG] Config not found or failed to load, using defaults.")
		display_settings["resolution"] = Vector2i(1920, 1080)
		display_settings["window_mode"] = DisplayServer.WINDOW_MODE_FULLSCREEN
		display_settings["borderless"] = false
		display_settings["vsync"] = true
		display_settings["brightness"] = 1.0
		display_settings["graphics_quality"] = 0
		display_settings["aa"] = 0

func _on_resolution_dropdown_item_selected(index: int) -> void:
	display_settings["resolution"] = resolutions[index]
	save_display_settings()

func save_display_settings():
	if enable_debug_logs:
		print("[DEBUG] Saving display settings to: ", display_config_path)
	var config = ConfigFile.new()
	config.set_value("display", "resolution", display_settings["resolution"])
	config.set_value("display", "window_mode", display_settings["window_mode"])
	config.set_value("display", "borderless", display_settings.get("borderless", false))
	config.set_value("display", "vsync", display_settings["vsync"])
	config.set_value("display", "brightness", display_settings["brightness"])
	config.set_value("display", "graphics_quality", display_settings.get("graphics_quality", 0))
	config.set_value("display", "aa", display_settings.get("aa", 0))
	DirAccess.make_dir_absolute(settings_dir) # Ensure directory exists
	var err = config.save(display_config_path)
	if err == OK and enable_debug_logs:
		print("[DEBUG] Config saved successfully.")
	else:
		if enable_debug_logs:
			print("[DEBUG] Failed to save config! Error code: ", err)

func _on_display_type_dropdown_item_selected(index: int) -> void:
	# 0: Fullscreen, 1: Window, 2: Borderless
	if index == 0:
		display_settings["window_mode"] = DisplayServer.WINDOW_MODE_FULLSCREEN
		display_settings["borderless"] = false
	elif index == 1:
		display_settings["window_mode"] = DisplayServer.WINDOW_MODE_WINDOWED
		display_settings["borderless"] = false
	elif index == 2:
		display_settings["window_mode"] = DisplayServer.WINDOW_MODE_WINDOWED
		display_settings["borderless"] = true
	save_display_settings()


func _on_vsync_button_toggled(toggled_on: bool) -> void:
	display_settings["vsync"] = toggled_on
	save_display_settings()

func _on_brightness_slider_value_changed(value: float) -> void:
	display_settings["brightness"] = value
	save_display_settings()

func apply_display_settings() -> void:
	if enable_debug_logs:
		print("[DEBUG] Applying display settings: ", display_settings)
	if display_settings.has("window_mode"):
		var prev_mode = DisplayServer.window_get_mode()
		var current_screen = DisplayServer.window_get_current_screen()
		var screen_size = DisplayServer.screen_get_size(current_screen)
		var screen_pos = DisplayServer.screen_get_position(current_screen)
		var desired_size = display_settings.get("resolution", Vector2i(1920, 1080))
		if display_settings["window_mode"] == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_size(desired_size)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, display_settings.get("borderless", false))
			var max_size = screen_size * 0.95
			var temp_scale = min(max_size.x / desired_size.x, max_size.y / desired_size.y, 1.0)
			var final_size = Vector2i(desired_size.x * temp_scale, desired_size.y * temp_scale)
			DisplayServer.window_set_size(final_size)
			if prev_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or temp_scale < 1.0:
				var pos = screen_pos + (screen_size - final_size) / 2
				DisplayServer.window_set_position(pos)
	if display_settings.has("vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if display_settings["vsync"] else DisplayServer.VSYNC_DISABLED)
		save_display_settings()
		if typeof(GraphicsSettingsManager) != TYPE_NIL:
			# Map display_settings to graphics_settings fields as needed
			var gq = display_settings.get("graphics_quality", 0)
			var aa = display_settings.get("aa", 0)
			# You can expand this mapping as needed
			GraphicsSettingsManager.graphics_settings["quality"] = gq
			GraphicsSettingsManager.graphics_settings["aa"] = aa
			# Optionally map more fields (e.g., LOD, texture_quality) here
			GraphicsSettingsManager.save_graphics_settings()
		else:
			if enable_debug_logs:
				print("[DEBUG] GraphicsSettingsManager singleton not found, graphics config not exported.")


func _on_graphics_quality_dropdown_item_selected(index: int) -> void:
	display_settings["graphics_quality"] = index
	save_display_settings()


func _on_aa_dropdown_item_selected(index: int) -> void:
	display_settings["aa"] = index
	save_display_settings()


#PROFILE SETTINGS
# --- GAME PROFILE SETTINGS ---
var profile_config_path = "user://settings/profile.cfg"
var profile_settings = {}
var game_profile_paths = [
	"res://assets/GameProfiles/VeryEasy.tres",
	"res://assets/GameProfiles/Easy.tres",
	"res://assets/GameProfiles/Medium.tres",
	"res://assets/GameProfiles/Hard.tres",
	"res://assets/GameProfiles/VeryHard.tres"
]
var game_profile_names = ["Very Easy", "Easy", "Medium", "Hard", "Very Hard"]
var loaded_profiles = []

func load_profile_settings():
	if enable_debug_logs:
		print("[DEBUG] Loading profile settings from: ", profile_config_path)
	var config = ConfigFile.new()
	var err = config.load(profile_config_path)
	if err == OK:
		profile_settings["selected"] = config.get_value("profile", "selected", 1) # Default to Easy (index 1)
		if enable_debug_logs:
			print("[DEBUG] Loaded profile settings: ", profile_settings)
	else:
		profile_settings["selected"] = 1 # Default to Easy

func save_profile_settings():
	if enable_debug_logs:
		print("[DEBUG] Saving profile settings to: ", profile_config_path)
	var config = ConfigFile.new()
	config.set_value("profile", "selected", profile_settings["selected"])
	DirAccess.make_dir_absolute(settings_dir)
	var err = config.save(profile_config_path)
	if err == OK and enable_debug_logs:
		print("[DEBUG] Profile config saved successfully.")
	else:
		if enable_debug_logs:
			print("[DEBUG] Failed to save profile config! Error code: ", err)

func load_game_profiles():
	loaded_profiles.clear()
	for path in game_profile_paths:
		var profile = load(path)
		loaded_profiles.append(profile)

func set_game_profile_menu_options():
	game_profile.clear()
	for name in game_profile_names:
		game_profile.add_item(name)
	game_profile.select(profile_settings.get("selected", 1))
	update_profile_labels(profile_settings.get("selected", 1))

func update_profile_labels(index: int):
	if index < 0 or index >= loaded_profiles.size():
		return
	var profile = loaded_profiles[index]
	if profile == null:
		return
	# Fill labels with correct GameProfileData.gd property names
	idle_moment_per.text = str(profile.idle_moment_thrust_percentage) + "%"
	thrust_lat.text = str(int(profile.thrust_latency * 1000)) + " ms"
	gimbal_lat.text = str(int(profile.gimbal_latency * 1000)) + " ms"
	vel_alin_coe.text = str(profile.velocity_alignment_coefficient)
	auto_stab.text = "On" if profile.auto_stabilization else "Off"
	stab_str.text = str(profile.stabilization_strength)
	roll_max_speed.text = str(profile.roll_max_speed) + " rad/s"
	roll_accel.text = str(profile.roll_acceleration) + " rad/s²"
	roll_damp.text = str(profile.roll_damping)
	description.text = str(profile.description)

func _on_game_profile_item_selected(index: int) -> void:
	profile_settings["selected"] = index
	update_profile_labels(index)

#CONTROLS SETTINGS
# --- CONTROLS SETTINGS ---
var controls_config_path = "user://settings/controls.cfg"
var controls_settings = {}
var controls_config_folder = "res://assets/Controls/"
var controls_config_files = ["Default.tres", "OnlyJoystick.tres", "OnlyKeyboard.tres", "RelaxedControls.tres"]
var controls_config_names = ["Default", "Only Joystick", "Only Keyboard", "Relaxed"]
var loaded_controls = []

func load_controls_settings():
	if enable_debug_logs:
		print("[DEBUG] Loading controls settings from: ", controls_config_path)
	var config = ConfigFile.new()
	var err = config.load(controls_config_path)
	if err == OK:
		controls_settings["selected"] = config.get_value("controls", "selected", 0) # Default to Default (index 0)
		if enable_debug_logs:
			print("[DEBUG] Loaded controls settings: ", controls_settings)
	else:
		controls_settings["selected"] = 0 # Default to Default

func save_controls_settings():
	if enable_debug_logs:
		print("[DEBUG] Saving controls settings to: ", controls_config_path)
	var config = ConfigFile.new()
	config.set_value("controls", "selected", controls_settings["selected"])
	DirAccess.make_dir_absolute(settings_dir)
	var err = config.save(controls_config_path)
	if err == OK and enable_debug_logs:
		print("[DEBUG] Controls config saved successfully.")
	else:
		if enable_debug_logs:
			print("[DEBUG] Failed to save controls config! Error code: ", err)

func load_controls_configs():
	loaded_controls.clear()
	for file in controls_config_files:
		var path = controls_config_folder + file
		var config = load(path)
		loaded_controls.append(config)

func set_controls_menu_options():
	controls_dropdown.clear()
	for name in controls_config_names:
		controls_dropdown.add_item(name)
	controls_dropdown.select(controls_settings.get("selected", 0))
	update_controls_labels(controls_settings.get("selected", 0))

func update_controls_labels(index: int):
	if index < 0 or index >= loaded_controls.size():
		return
	var config = loaded_controls[index]
	if config == null:
		return
	description_controls.text = str(config.description)
	return_anim_dur.text = str(int(config.return_animation_duration*1000)) + " ms"
	ret_anim_trans.text = return_anim_trans_names[config.return_animation_trans]
	thr_incrm_per_sec.text = str(config.throttle_increment_per_second) + " per second"
	throtle_joystick_deadzone.text = str(config.throttle_joystick_deadzone)
	throtle_cooldown.text = str(int(config.throttle_joystick_cooldown_time*1000)) + " ms"
	joystick_deadzone.text = str(config.deadzone_joystick)
	enable_keyboard.text = "Yes" if config.enable_keyboard_input else "No"
	mouse_deadzone.text = str(config.deadzone_mouse)

func _on_controls_dropdown_item_selected(index: int) -> void:
	controls_settings["selected"] = index
	update_controls_labels(index)

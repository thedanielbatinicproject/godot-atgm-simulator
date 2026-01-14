extends Control

var scroll_speed := 300 # pixels per second
var scroll_accel_time := 1.5 # seconds to accelerate
var scroll_accel_factor := 5.0 # speed multiplier after acceleration
var scroll_up_hold_time := 0.0
var scroll_down_hold_time := 0.0

@onready var main_menu_root: VBoxContainer = $"../MainMenuRoot"
@onready var scenario_selector: Control = $"."

# --- SCENARIO SELECTOR SCROLL AREA ---
@export var enable_scenario_loading: bool = true
@onready var scenarios_list: VBoxContainer = $SceneRoot/MainContentBox/HBoxContainer/ScrollableArea/MarginContainer/ScenarioList/ScrollContainer/ScenarioBox/ScenariosList
@onready var scenario_item_1: Button = $SceneRoot/MainContentBox/HBoxContainer/ScrollableArea/MarginContainer/ScenarioList/ScrollContainer/ScenarioBox/ScenariosList/ScenarioItem1
@onready var scroll_container: ScrollContainer = $SceneRoot/MainContentBox/HBoxContainer/ScrollableArea/MarginContainer/ScenarioList/ScrollContainer

@onready var scenario_data_display: HBoxContainer = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer

# --- DATA ITEMS ---
@onready var scenario_description: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/VBoxContainer/Desc/ScenarioDescription
@onready var level_name: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/VBoxContainer/LevelName/LevelName
@onready var proj_model_name: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/VBoxContainer/RocketModel/ProjModelName
@onready var proj_max_thrust: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/VBoxContainer/RocketThrust/ProjMaxThrust
@onready var proj_thrust_max_angle: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/VBoxContainer/RocketMaxAngle/ProjThrustMaxAngle
@onready var proj_weight: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/VBoxContainer/RocketMass/ProjWeight
@onready var proj_len: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/VBoxContainer/RocketLenght/ProjLen
@onready var proj_radius: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer/MarginContainer/VBoxContainer/RocketRadisu/ProjRadius
@onready var proj_initial_speed: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VBoxContainer/InitialSpeed/ProjInitialSpeed
@onready var time_of_day: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VBoxContainer/TimeOfDay/TimeOfDay
@onready var wind_type: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VBoxContainer/Wind/WindType
@onready var wind_strenght: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VBoxContainer/WindStr/WindStrenght
@onready var tank_name: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VBoxContainer/TankModel/TankName
@onready var other_conditions_fog: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VBoxContainer/Other/OtherConditionsFog
@onready var selected_profile: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VBoxContainer/Profile/SelectedProfile
@onready var selected_controls: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VBoxContainer/Controls/SelectedControls
@onready var difficulty: Label = $SceneRoot/MainContentBox/HBoxContainer/ScenarioDetails/HBoxContainer/MarginContainer/HBoxContainer/BoxContainer2/MarginContainer/VBoxContainer/Controls2/Difficulty

# --- SCENARIO DATA ARRAY (for export inclusion and editor management) ---
@export var scenario_data_array: Array[Resource] = [] # Fill with ScenarioData .tres in the editor


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	scenario_data_display.visible = false
	if enable_scenario_loading:
		populate_scenarios_list()

func _process(delta):
	if Input.is_action_pressed("scroll_up"):
		scroll_up_hold_time += delta
		var speed = scroll_speed
		if scroll_up_hold_time > scroll_accel_time:
			speed *= scroll_accel_factor
		scroll_container.scroll_vertical += speed * delta
	else:
		scroll_up_hold_time = 0.0
	if Input.is_action_pressed("scroll_down"):
		scroll_down_hold_time += delta
		var speed = scroll_speed
		if scroll_down_hold_time > scroll_accel_time:
			speed *= scroll_accel_factor
		scroll_container.scroll_vertical -= speed * delta
	else:
		scroll_down_hold_time = 0.0

# Populates the scenario list with all scenario .tres files in /assets/Scenarios
func populate_scenarios_list() -> void:
	# Remove all scenario items except ScenarioItem1 (keep styles)
	for i in range(scenarios_list.get_child_count() - 1, 0, -1):
		var child := scenarios_list.get_child(i)
		if child != scenario_item_1:
			child.queue_free()

	# Placeholder values
	var default_thumb: Texture2D = load("res://assets/UI/MainMenu/Graphics/scenario_thumb_placeholder.png")
	var default_name := "Scenario"

	for i in range(scenario_data_array.size()):
		var scenario_res = scenario_data_array[i]
		if scenario_res == null:
			continue

		var scenario_name := default_name
		var scenario_thumb := default_thumb

		if "scenario_name" in scenario_res and typeof(scenario_res.scenario_name) == TYPE_STRING and scenario_res.scenario_name != "":
			scenario_name = scenario_res.scenario_name

		if "scenario_thumbnail" in scenario_res and scenario_res.scenario_thumbnail != null:
			scenario_thumb = scenario_res.scenario_thumbnail

		var item: Button

		if i == 0:
			item = scenario_item_1
		else:
			item = scenario_item_1.duplicate()
			scenarios_list.add_child(item)

		# --- UI hierarchy ---
		var margin := item.get_child(0)            # ScenarioItemMargin
		var vbox := margin.get_child(0)            # ScenarioThumbAndTitle
		var thumb := vbox.get_child(0)             # TextureRect
		var title := vbox.get_child(1)             # Label

		if thumb is TextureRect:
			thumb.texture = scenario_thumb

		if title is Label:
			title.text = scenario_name

		# Store scenario resource
		item.set_meta("scenario_res", scenario_res)

		# Connect signal (avoid duplicates)
		var callable := Callable(self, "_on_scenario_item_pressed").bind(item)

		if item.is_connected("pressed", callable):
			item.disconnect("pressed", callable)

		item.pressed.connect(callable)




func _on_scenario_item_pressed(item: Button) -> void:
	scenario_data_display.visible = true
	var scenario_res = item.get_meta("scenario_res")
	if scenario_res == null:
		return

	# Scenario description and name
	scenario_description.text = scenario_res.scenario_description if "scenario_description" in scenario_res else ""

	# Level name: show only file name, no extension
	var level_path: String = (scenario_res.level_scene.resource_path if "level_scene" in scenario_res and scenario_res.level_scene else "")
	var level_file: String = ""
	if level_path != "":
		var parts = level_path.split("/")
		level_file = parts[parts.size() - 1].get_basename() # removes extension
	level_name.text = level_file

	difficulty.text = scenario_res.scenario_difficulty if "scenario_difficulty" in scenario_res else ""

	# Tank
	tank_name.text = scenario_res.tank_name if "tank_name" in scenario_res else ""

	# Projectile
	if "rocket_data" in scenario_res and scenario_res.rocket_data:
		var rocket = scenario_res.rocket_data
		# Use rocket_name
		proj_model_name.text = rocket.rocket_name if "rocket_name" in rocket else ""
		# Max thrust with N
		proj_max_thrust.text = (str(rocket.max_thrust) + " N") if "max_thrust" in rocket else ""
		# Max thrust angle in degrees, 2 decimals, with °
		if "max_thrust_angle" in rocket:
			var deg = rad_to_deg(rocket.max_thrust_angle)
			proj_thrust_max_angle.text = "%.2f°" % deg
		else:
			proj_thrust_max_angle.text = ""
		# Mass in kg
		proj_weight.text = ("%.1f kg" % rocket.mass) if "mass" in rocket else ""
		# Length in cm (cylinder_height + cone_height)
		if "cylinder_height" in rocket and "cone_height" in rocket:
			var len_cm = (rocket.cylinder_height + rocket.cone_height) * 100.0
			proj_len.text = "%.2f cm" % len_cm
		else:
			proj_len.text = ""
		# Diameter in cm
		if "radius" in rocket:
			proj_radius.text = "%.2f cm" % (rocket.radius * 100.0 *2 ) # diameter
		else:
			proj_radius.text = ""
	else:
		proj_model_name.text = ""
		proj_max_thrust.text = ""
		proj_thrust_max_angle.text = ""
		proj_weight.text = ""
		proj_len.text = ""
		proj_radius.text = ""

	# Initial speed in mps
	if "initial_speed" in scenario_res:
		proj_initial_speed.text = str(scenario_res.initial_speed) + " mps"
	else:
		proj_initial_speed.text = ""

	# Environment
	# Time of day: float 0-24 to HH:MM AM/PM
	if "time_of_day" in scenario_res:
		var tod = scenario_res.time_of_day
		var hour = int(tod) % 24
		var minute = int(round((tod - hour) * 60.0))
		if minute == 60:
			hour += 1
			minute = 0
		var ampm = "AM"
		var display_hour = hour
		if hour == 0:
			display_hour = 12
		elif hour == 12:
			ampm = "PM"
		elif hour > 12:
			display_hour = hour - 12
			ampm = "PM"
		time_of_day.text = "%d:%02d %s" % [display_hour, minute, ampm]
	else:
		time_of_day.text = ""

	wind_type.text = scenario_res.wind_type if "wind_type" in scenario_res else ""
	wind_strenght.text = str(scenario_res.wind_base_vector.length()) if "wind_base_vector" in scenario_res else ""

	# Other conditions: fog density to CLEAR/FOGGY/FOG (hard)
	if "fog_density" in scenario_res:
		var fog = scenario_res.fog_density
		if fog < 0.3:
			other_conditions_fog.text = "CLEAR"
		elif fog <= 0.8:
			other_conditions_fog.text = "FOGGY"
		else:
			other_conditions_fog.text = "FOG (hard)"
	else:
		other_conditions_fog.text = ""

	# Profile and controls (user-selected, not scenario)
	var profile_index: int
	var controls_index: int
	var profile_cfg = ConfigFile.new()
	if profile_cfg.load("user://settings/profile.cfg") == OK:
		profile_index = int(profile_cfg.get_value("profile", "selected", 1))
	else:
		profile_index = 1
	var controls_cfg = ConfigFile.new()
	if controls_cfg.load("user://settings/controls.cfg") == OK:
		controls_index = int(controls_cfg.get_value("controls", "selected", 0))
	else:
		controls_index = 0

	var profile_paths = [
		"res://assets/GameProfiles/VeryEasy.tres",
		"res://assets/GameProfiles/Easy.tres",
		"res://assets/GameProfiles/Medium.tres",
		"res://assets/GameProfiles/Hard.tres",
		"res://assets/GameProfiles/VeryHard.tres"
	]
	var controls_paths = [
		"res://assets/Controls/Default.tres",
		"res://assets/Controls/OnlyJoystick.tres",
		"res://assets/Controls/OnlyKeyboard.tres",
		"res://assets/Controls/RelaxedControls.tres"
	]

	var profile_res = null
	var controls_res = null
	if profile_index < profile_paths.size():
		profile_res = load(profile_paths[profile_index])
	else:
		profile_res = load(profile_paths[1])
	if controls_index < controls_paths.size():
		controls_res = load(controls_paths[controls_index])
	else:
		controls_res = load(controls_paths[0])

	selected_profile.text = profile_res.profile_name if profile_res and "profile_name" in profile_res else ""
	selected_controls.text = controls_res.name if controls_res and "name" in controls_res else ""

func _on_return_btn_pressed() -> void:
	scenario_data_display.visible = false
	scenario_selector.visible = false
	if main_menu_root:
		main_menu_root.visible = true

#func _process(delta):
#	if Input.is_action_pressed("scroll_up"):
#		scroll_container.scroll_vertical += scroll_speed * delta
#	if Input.is_action_pressed("scroll_down"):
#		scroll_container.scroll_vertical -= scroll_speed * delta

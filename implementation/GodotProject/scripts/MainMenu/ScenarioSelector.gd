extends Control

# Scenario selector for main menu

signal scenario_selected(scenario_data)

var selected_scenario = null



func _ready():
	var scenario_dir = "res://assets/Scenarios"
	var scenario_paths = []
	var dir = DirAccess.open(scenario_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				scenario_paths.append(scenario_dir + "/" + file_name)
			file_name = dir.get_next()
		var scenarios = []
		for path in scenario_paths:
			var res = load(path)
			if res:
				scenarios.append(res)
		set_scenarios(scenarios)

	$Footer/BackButton.pressed.connect(_on_back_pressed)
	$Footer/StartButton.pressed.connect(_on_start_pressed)

func _on_back_pressed():
	get_parent().get_node("MainMenuTransitions").show_main_menu()

func _on_start_pressed():
	if selected_scenario and selected_scenario.level_scene:
		get_tree().change_scene_to_packed(selected_scenario.level_scene)


func set_scenarios(scenarios: Array):
	var grid = $Scroll/Grid
	for c in grid.get_children():
		c.queue_free()
	for scenario in scenarios:
		var item = preload("res://scenes/UI/MainMenu/ScenarioGridItem.tscn").instantiate()
		item.setup(scenario)
		item.connect("selected", Callable(self, "_on_scenario_selected"))
		grid.add_child(item)

func _on_scenario_selected(item):
	for c in $Scroll/Grid.get_children():
		c.modulate = Color(1,1,1,1)
	item.modulate = Color(0.5,0.8,1,1)
	select_scenario(item.scenario_data)

func select_scenario(scenario_data):
	selected_scenario = scenario_data
	emit_signal("scenario_selected", scenario_data)

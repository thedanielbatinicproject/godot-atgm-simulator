extends Node

var menu_root
var scenario_selector

func _ready():
	menu_root = get_parent()
	scenario_selector = menu_root.get_node_or_null("../ScenarioSelector")

func show_scenario_selector():
	if scenario_selector:
		scenario_selector.visible = true
		menu_root.visible = false

func show_main_menu():
	if scenario_selector:
		scenario_selector.visible = false
		menu_root.visible = true

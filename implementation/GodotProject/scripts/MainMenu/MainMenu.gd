extends Control


@onready var transitions = $MainMenuTransitions
@onready var scenario_selector = $ScenarioSelector
@onready var button_start = $VBox/ButtonStart
@onready var button_options = $VBox/ButtonOptions
@onready var button_quit = $VBox/ButtonQuit

func _ready():
	button_start.pressed.connect(_on_start_pressed)
	button_options.pressed.connect(_on_options_pressed)
	button_quit.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	transitions.show_scenario_selector()

func _on_options_pressed():
	# Placeholder for options menu
	pass

func _on_quit_pressed():
	get_tree().quit()

extends Node

# ============================================================================
# SCENARIO MANAGER (SINGLETON)
# ============================================================================
# Main orchestrator for scenario lifecycle, integrating all sub-managers.
# Add to Project Settings -> Autoload as "ScenarioManager"
# ============================================================================

# Preload sub-manager scripts for type safety
const ScenarioStateClass = preload("res://scripts/ScenarioManager/ScenarioState.gd")
const ScenarioLoaderClass = preload("res://scripts/ScenarioManager/ScenarioLoader.gd")
const ScenarioEnvironmentClass = preload("res://scripts/ScenarioManager/ScenarioEnvironment.gd")
const ScenarioEventWatcherClass = preload("res://scripts/ScenarioManager/ScenarioEventWatcher.gd")
const ScenarioCutsceneManagerClass = preload("res://scripts/ScenarioManager/ScenarioCutsceneManager.gd")
const NarratorManagerClass = preload("res://scripts/ScenarioManager/NarratorManager.gd")

signal scenario_loading_started
signal scenario_started
signal scenario_paused
signal scenario_resumed
signal scenario_completed(success: bool)
signal player_control_changed(enabled: bool)

# Sub-managers
var state
var loader
var environment
var event_watcher
var cutscene_manager
var narrator

# Current scenario data
var current_scenario_data: ScenarioData = null
var _scenario_root: Node = null
var _hud_layer: CanvasLayer = null
var _pause_menu: Control = null

# Configuration
@export var pause_menu_scene: PackedScene
@export var hud_scene: PackedScene
@export var end_screen_scene: PackedScene


func _ready() -> void:
	# Initialize sub-managers
	state = ScenarioStateClass.new()
	
	loader = ScenarioLoaderClass.new()
	add_child(loader)
	
	environment = ScenarioEnvironmentClass.new()
	add_child(environment)
	
	event_watcher = ScenarioEventWatcherClass.new()
	add_child(event_watcher)
	
	cutscene_manager = ScenarioCutsceneManagerClass.new()
	add_child(cutscene_manager)
	
	narrator = NarratorManagerClass.new()
	add_child(narrator)
	
	# Connect signals
	_connect_signals()


func _connect_signals() -> void:
	# State changes
	state.state_changed.connect(_on_state_changed)
	
	# Loader signals
	loader.loading_started.connect(_on_loading_started)
	loader.loading_completed.connect(_on_loading_completed)
	loader.loading_failed.connect(_on_loading_failed)
	
	# Event watcher signals
	event_watcher.projectile_hit_tank.connect(_on_projectile_hit_tank)
	event_watcher.projectile_hit_ground.connect(_on_projectile_hit_ground)
	event_watcher.projectile_out_of_bounds.connect(_on_projectile_out_of_bounds)
	event_watcher.cutscene_distance_reached.connect(_on_cutscene_distance_reached)
	event_watcher.scenario_timeout.connect(_on_scenario_timeout)
	event_watcher.player_control_delay_finished.connect(_on_player_control_delay_finished)
	
	# Cutscene signals
	cutscene_manager.cutscene_finished.connect(_on_cutscene_finished)
	cutscene_manager.hit_animation_finished.connect(_on_hit_animation_finished)
	cutscene_manager.miss_animation_finished.connect(_on_miss_animation_finished)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_toggle"):
		if state.is_state(ScenarioStateClass.State.RUNNING):
			pause_scenario()
		elif state.is_state(ScenarioStateClass.State.PAUSED):
			resume_scenario()


func _process(delta: float) -> void:
	if not state.is_active():
		return
	
	# Process sub-managers
	if state.is_state(ScenarioStateClass.State.RUNNING):
		event_watcher.process(delta)
		narrator.process(delta)
	
	if state.is_state(ScenarioStateClass.State.CUTSCENE):
		cutscene_manager.process_cutscene(delta)


# ============================================================================
# PUBLIC API
# ============================================================================

func start_scenario(scenario_data: ScenarioData) -> void:
	"""Called from main menu to start a scenario."""
	if state.is_active():
		push_warning("ScenarioManager: Cannot start scenario while another is active")
		return
	
	current_scenario_data = scenario_data
	scenario_loading_started.emit()
	
	# Clear current scene (main menu)
	_clear_current_scene()
	
	# Transition to loading state
	state.transition_to(ScenarioStateClass.State.LOADING)
	
	# Start loading
	loader.start_loading(scenario_data)


func pause_scenario() -> void:
	if not state.can_transition_to(ScenarioStateClass.State.PAUSED):
		return
	
	state.transition_to(ScenarioStateClass.State.PAUSED)
	get_tree().paused = true
	_show_pause_menu()
	scenario_paused.emit()


func resume_scenario() -> void:
	if not state.can_transition_to(ScenarioStateClass.State.RUNNING):
		return
	
	_hide_pause_menu()
	get_tree().paused = false
	state.transition_to(ScenarioStateClass.State.RUNNING)
	scenario_resumed.emit()


func exit_scenario() -> void:
	"""Exit current scenario and return to main menu."""
	_cleanup_scenario()
	state.reset()
	
	# Load main menu scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu/MainMenu.tscn")


func get_scenario_time() -> float:
	return event_watcher.get_scenario_time()


func is_player_control_enabled() -> bool:
	return state.is_player_control_enabled() and event_watcher.is_player_control_enabled()


# ============================================================================
# INTERNAL METHODS
# ============================================================================

func _clear_current_scene() -> void:
	# Get current scene and free it
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.queue_free()


func _on_loading_started() -> void:
	pass  # Loading screen is handled by loader


func _on_loading_completed(scenario_root: Node) -> void:
	_scenario_root = scenario_root
	
	# Add scenario root to tree
	get_tree().root.add_child(_scenario_root)
	get_tree().current_scene = _scenario_root
	
	# Setup environment
	environment.setup_environment(_scenario_root, current_scenario_data)
	
	# Create HUD layer
	_create_hud()
	
	# Setup narrator
	if _hud_layer:
		narrator.setup(current_scenario_data, _hud_layer)
	
	# Transition to starting state
	state.transition_to(ScenarioStateClass.State.STARTING)
	
	# Start event watching
	event_watcher.start_watching(_scenario_root, current_scenario_data)
	
	# Transition to running (player control depends on delay)
	state.transition_to(ScenarioStateClass.State.RUNNING)
	player_control_changed.emit(false)  # Initially disabled until delay passes
	
	scenario_started.emit()


func _on_loading_failed(error: String) -> void:
	push_error("ScenarioManager: Loading failed - " + error)
	state.reset()
	
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu/MainMenu.tscn")


func _on_state_changed(old_state: int, new_state: int) -> void:
	print("ScenarioManager: State changed from %s to %s" % [
		ScenarioStateClass.State.keys()[old_state],
		ScenarioStateClass.State.keys()[new_state]
	])


func _on_player_control_delay_finished() -> void:
	if state.is_state(ScenarioStateClass.State.RUNNING):
		player_control_changed.emit(true)
		narrator.play_default_message("You have control!", 2.0)


func _on_cutscene_distance_reached() -> void:
	if not state.can_transition_to(ScenarioStateClass.State.CUTSCENE):
		return
	
	# Disable player control
	player_control_changed.emit(false)
	
	# Start cutscene
	state.transition_to(ScenarioStateClass.State.CUTSCENE)
	
	var projectile = event_watcher.get_projectile()
	var tank = event_watcher.get_tank()
	cutscene_manager.start_final_cutscene(projectile, tank)


func _on_projectile_hit_tank() -> void:
	# Play hit animation
	var projectile = event_watcher.get_projectile()
	var hit_pos = projectile.global_position if projectile else Vector3.ZERO
	cutscene_manager.play_hit_animation(hit_pos)
	
	narrator.play_default_message("TARGET DESTROYED!", 3.0)


func _on_projectile_hit_ground(position: Vector3) -> void:
	# Transition to cutscene if not already
	if state.is_state(ScenarioStateClass.State.RUNNING):
		state.transition_to(ScenarioStateClass.State.CUTSCENE)
		player_control_changed.emit(false)
	
	# Play miss animation
	cutscene_manager.play_miss_animation(position)
	
	narrator.play_default_message("MISSED! Target survived.", 3.0)


func _on_projectile_out_of_bounds() -> void:
	_end_scenario(false, "OUT OF BOUNDS")


func _on_scenario_timeout() -> void:
	_end_scenario(false, "TIME'S UP")


func _on_cutscene_finished() -> void:
	pass  # Wait for animation to finish


func _on_hit_animation_finished() -> void:
	_end_scenario(true, "MISSION COMPLETE")


func _on_miss_animation_finished() -> void:
	_end_scenario(false, "MISSION FAILED")


func _end_scenario(success: bool, message: String) -> void:
	var target_state = ScenarioStateClass.State.COMPLETED if success else ScenarioStateClass.State.FAILED
	
	if state.can_transition_to(target_state):
		state.transition_to(target_state)
	
	scenario_completed.emit(success)
	
	# Show end screen
	_show_end_screen(success, message)


func _create_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDLayer"
	_hud_layer.layer = 10
	_scenario_root.add_child(_hud_layer)
	
	if hud_scene:
		var hud = hud_scene.instantiate()
		_hud_layer.add_child(hud)


func _show_pause_menu() -> void:
	if pause_menu_scene and _hud_layer:
		_pause_menu = pause_menu_scene.instantiate()
		_hud_layer.add_child(_pause_menu)
		
		# Connect pause menu signals if available
		if _pause_menu.has_signal("resume_pressed"):
			_pause_menu.connect("resume_pressed", resume_scenario)
		if _pause_menu.has_signal("exit_pressed"):
			_pause_menu.connect("exit_pressed", exit_scenario)
	else:
		# Fallback: create simple pause overlay
		_pause_menu = ColorRect.new()
		_pause_menu.color = Color(0, 0, 0, 0.7)
		_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		var label = Label.new()
		label.text = "PAUSED\n\nPress pause_toggle to resume\nPress ESC to exit"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_CENTER)
		_pause_menu.add_child(label)
		
		if _hud_layer:
			_hud_layer.add_child(_pause_menu)


func _hide_pause_menu() -> void:
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null


func _show_end_screen(success: bool, message: String) -> void:
	if end_screen_scene and _hud_layer:
		var end_screen = end_screen_scene.instantiate()
		_hud_layer.add_child(end_screen)
		
		# Try to set message
		if end_screen.has_method("set_result"):
			end_screen.set_result(success, message)
	else:
		# Fallback: create simple end screen
		var end_panel = ColorRect.new()
		end_panel.color = Color(0, 0, 0, 0.8)
		end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_CENTER)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		end_panel.add_child(vbox)
		
		var title = Label.new()
		title.text = message
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 48)
		vbox.add_child(title)
		
		var subtitle = Label.new()
		subtitle.text = "SUCCESS!" if success else "TRY AGAIN"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_color_override("font_color", Color.GREEN if success else Color.RED)
		vbox.add_child(subtitle)
		
		var spacer = Control.new()
		spacer.custom_minimum_size.y = 50
		vbox.add_child(spacer)
		
		var exit_btn = Button.new()
		exit_btn.text = "Return to Menu"
		exit_btn.pressed.connect(exit_scenario)
		vbox.add_child(exit_btn)
		
		if _hud_layer:
			_hud_layer.add_child(end_panel)


func _cleanup_scenario() -> void:
	# Stop all sub-managers
	event_watcher.stop_watching()
	cutscene_manager.cleanup()
	narrator.cleanup()
	environment.cleanup()
	
	# Unload scenario
	loader.unload_scenario()
	
	# Clean up HUD
	if _hud_layer:
		_hud_layer.queue_free()
		_hud_layer = null
	
	_pause_menu = null
	_scenario_root = null
	current_scenario_data = null

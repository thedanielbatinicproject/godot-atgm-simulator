extends Node

class_name NarratorManager

# ============================================================================
# NARRATOR MANAGER
# ============================================================================
# Military general narrator with speech bubble, animated mouth, typing text.
# ============================================================================

signal voice_line_started(index: int)
signal voice_line_finished(index: int)
signal all_voice_lines_finished

@export var narrator_scene: PackedScene  # Scene with general sprite, speech bubble, etc.
@export var typing_speed: float = 30.0  # Characters per second
@export var default_rumble_audio: AudioStream  # Default audio when no voice lines

# UI References (set after instantiating narrator_scene)
var _narrator_container: Control = null
var _general_sprite: AnimatedSprite2D = null
var _speech_bubble: Control = null
var _subtitle_label: Label = null
var _audio_player: AudioStreamPlayer = null

var _scenario_data: ScenarioData = null
var _current_voice_line_index: int = -1
var _voice_line_queue: Array[int] = []
var _scenario_time: float = 0.0
var _is_typing: bool = false
var _typing_text: String = ""
var _typing_progress: float = 0.0

var _scheduled_lines: Array[Dictionary] = []  # {time: float, index: int, triggered: bool}


func setup(scenario_data: ScenarioData, ui_parent: Node) -> void:
	_scenario_data = scenario_data
	_scenario_time = 0.0
	_current_voice_line_index = -1
	_voice_line_queue.clear()
	_scheduled_lines.clear()
	
	# Create narrator UI
	_create_narrator_ui(ui_parent)
	
	# Schedule voice lines
	_schedule_voice_lines()


func _create_narrator_ui(ui_parent: Node) -> void:
	if narrator_scene:
		_narrator_container = narrator_scene.instantiate()
		ui_parent.add_child(_narrator_container)
		
		# Find child nodes
		_general_sprite = _narrator_container.get_node_or_null("GeneralSprite")
		_speech_bubble = _narrator_container.get_node_or_null("SpeechBubble")
		_subtitle_label = _narrator_container.get_node_or_null("SpeechBubble/SubtitleLabel")
		_audio_player = _narrator_container.get_node_or_null("AudioPlayer")
	else:
		# Create fallback narrator UI
		_create_fallback_narrator_ui(ui_parent)
	
	# Initially hidden
	if _narrator_container:
		_narrator_container.visible = false


func _create_fallback_narrator_ui(ui_parent: Node) -> void:
	_narrator_container = Control.new()
	_narrator_container.name = "NarratorContainer"
	_narrator_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_narrator_container.position = Vector2(-350, -200)
	_narrator_container.size = Vector2(300, 180)
	ui_parent.add_child(_narrator_container)
	
	# Background panel
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narrator_container.add_child(panel)
	
	# General "sprite" placeholder
	var general_rect = ColorRect.new()
	general_rect.name = "GeneralPlaceholder"
	general_rect.color = Color(0.3, 0.4, 0.3)
	general_rect.size = Vector2(80, 100)
	general_rect.position = Vector2(10, 40)
	_narrator_container.add_child(general_rect)
	
	# General label
	var general_label = Label.new()
	general_label.text = "GEN"
	general_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	general_label.position = Vector2(10, 70)
	general_label.size = Vector2(80, 30)
	_narrator_container.add_child(general_label)
	
	# Speech bubble
	_speech_bubble = Panel.new()
	_speech_bubble.name = "SpeechBubble"
	_speech_bubble.size = Vector2(200, 120)
	_speech_bubble.position = Vector2(95, 20)
	_narrator_container.add_child(_speech_bubble)
	
	# Subtitle label
	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(_subtitle_label)
	_speech_bubble.add_child(margin)
	
	# Audio player
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioPlayer"
	_narrator_container.add_child(_audio_player)


func _schedule_voice_lines() -> void:
	if not _scenario_data:
		return
	
	var count = _scenario_data.get_voice_line_count()
	
	if count == 0:
		# No voice lines - we'll use default rumble when needed
		return
	
	for i in range(count):
		var voice_line = _scenario_data.get_voice_line(i)
		_scheduled_lines.append({
			"time": voice_line.time,
			"index": i,
			"triggered": false
		})
	
	# Sort by time
	_scheduled_lines.sort_custom(func(a, b): return a.time < b.time)


func process(delta: float) -> void:
	_scenario_time += delta
	
	# Check for scheduled voice lines
	_check_scheduled_lines()
	
	# Process typing animation
	_process_typing(delta)
	
	# Animate general mouth if speaking
	_animate_general_mouth()


func _check_scheduled_lines() -> void:
	for line_data in _scheduled_lines:
		if not line_data.triggered and _scenario_time >= line_data.time:
			line_data.triggered = true
			play_voice_line(line_data.index)


func play_voice_line(index: int) -> void:
	if not _scenario_data:
		return
	
	var voice_line = _scenario_data.get_voice_line(index)
	
	_current_voice_line_index = index
	voice_line_started.emit(index)
	
	# Show narrator
	if _narrator_container:
		_narrator_container.visible = true
	
	# Start typing animation
	_start_typing(voice_line.text)
	
	# Play audio
	if voice_line.audio and _audio_player:
		_audio_player.stream = voice_line.audio
		_audio_player.play()
	elif default_rumble_audio and _audio_player:
		_audio_player.stream = default_rumble_audio
		_audio_player.play()


func play_default_message(text: String, duration: float = 3.0) -> void:
	# For showing messages without predefined voice lines
	if _narrator_container:
		_narrator_container.visible = true
	
	_start_typing(text)
	
	if default_rumble_audio and _audio_player:
		_audio_player.stream = default_rumble_audio
		_audio_player.play()
	
	# Auto-hide after duration
	await get_tree().create_timer(duration + text.length() / typing_speed).timeout
	hide_narrator()


func _start_typing(text: String) -> void:
	_typing_text = text
	_typing_progress = 0.0
	_is_typing = true
	
	if _subtitle_label:
		_subtitle_label.text = ""


func _process_typing(delta: float) -> void:
	if not _is_typing or _typing_text.is_empty():
		return
	
	_typing_progress += typing_speed * delta
	var chars_to_show = int(_typing_progress)
	
	if chars_to_show >= _typing_text.length():
		# Typing finished
		if _subtitle_label:
			_subtitle_label.text = _typing_text
		_is_typing = false
		_on_typing_finished()
	else:
		if _subtitle_label:
			_subtitle_label.text = _typing_text.substr(0, chars_to_show)


func _on_typing_finished() -> void:
	if _current_voice_line_index >= 0:
		voice_line_finished.emit(_current_voice_line_index)
		
		# Check if all lines finished
		var all_triggered = true
		for line_data in _scheduled_lines:
			if not line_data.triggered:
				all_triggered = false
				break
		
		if all_triggered and _scheduled_lines.size() > 0:
			# Wait a moment then hide
			await get_tree().create_timer(2.0).timeout
			hide_narrator()
			all_voice_lines_finished.emit()


func _animate_general_mouth() -> void:
	if not _general_sprite:
		return
	
	# Simple mouth animation: alternate frames while speaking
	if _is_typing or (_audio_player and _audio_player.playing):
		# Animate mouth open/closed
		var frame = int(Time.get_ticks_msec() / 100) % 2
		if _general_sprite.sprite_frames and _general_sprite.sprite_frames.has_animation("talking"):
			_general_sprite.play("talking")
		else:
			# Fallback: just use frame index if available
			if _general_sprite.sprite_frames:
				_general_sprite.frame = frame
	else:
		# Idle
		if _general_sprite.sprite_frames and _general_sprite.sprite_frames.has_animation("idle"):
			_general_sprite.play("idle")
		else:
			_general_sprite.frame = 0


func hide_narrator() -> void:
	if _narrator_container:
		_narrator_container.visible = false
	
	if _audio_player:
		_audio_player.stop()
	
	_is_typing = false


func show_narrator() -> void:
	if _narrator_container:
		_narrator_container.visible = true


func cleanup() -> void:
	hide_narrator()
	
	if _narrator_container:
		_narrator_container.queue_free()
		_narrator_container = null
	
	_scenario_data = null
	_scheduled_lines.clear()


func is_speaking() -> bool:
	return _is_typing or (_audio_player and _audio_player.playing)

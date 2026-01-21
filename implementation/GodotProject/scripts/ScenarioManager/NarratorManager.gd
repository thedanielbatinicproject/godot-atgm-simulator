extends Node

class_name NarratorManager

# ============================================================================
# NARRATOR MANAGER
# ============================================================================
# Military general narrator with speech bubble, animated mouth, typing text.
# Uses mumbling placeholder audio when voice lines have text but no audio.
# ============================================================================

signal voice_line_started(index: int)
signal voice_line_finished(index: int)
signal all_voice_lines_finished

@export var narrator_scene: PackedScene  # Scene with general sprite, speech bubble, etc.
@export var typing_speed: float = 30.0  # Characters per second
@export var default_rumble_audio: AudioStream  # Default audio when no voice lines

# Preload mumbling audio
const MUMBLE_1 = preload("res://assets/Audio/Voice/GeneralPlaceholder/mumble1.wav")
const MUMBLE_2 = preload("res://assets/Audio/Voice/GeneralPlaceholder/mumble2.wav")

# Preload general graphics
const GENERAL_IDLE = preload("res://assets/UI/HUD/Graphics/general.png")
const GENERAL_TALK_1 = preload("res://assets/UI/HUD/Graphics/GENERAL_TALK/general1.png")
const GENERAL_TALK_2 = preload("res://assets/UI/HUD/Graphics/GENERAL_TALK/general2.png")
const GENERAL_TALK_3 = preload("res://assets/UI/HUD/Graphics/GENERAL_TALK/general3.png")
const GENERAL_TALK_4 = preload("res://assets/UI/HUD/Graphics/GENERAL_TALK/general4.png")

# UI References (set after instantiating narrator_scene)
var _narrator_container: Control = null
var _general_sprite: TextureRect = null  # Changed to TextureRect for texture switching
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

# Mumbling audio state
var _use_mumbling: bool = false
var _current_mumble_index: int = 0
var _talk_frame_index: int = 0
var _talk_frame_timer: float = 0.0
const TALK_FRAME_DURATION: float = 0.1  # 100ms per frame for talk animation
const VOICE_LINE_COOLDOWN: float = 3.0  # 3 seconds cooldown after each voice line
const DEFAULT_CHARS_PER_SECOND: float = 8.0  # Typing speed when no audio (8 chars/sec)

# Current voice line audio duration (for syncing text with audio)
var _current_audio_duration: float = 0.0


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
		# Create fallback narrator UI with fixed size
		_create_fallback_narrator_ui(ui_parent)
	
	# Set initial general texture (idle)
	if _general_sprite:
		_general_sprite.texture = GENERAL_IDLE
	
	# Initially hidden
	if _narrator_container:
		_narrator_container.visible = false


func _create_fallback_narrator_ui(ui_parent: Node) -> void:
	# Fixed size container for narrator popup
	var popup_width: float = 350.0
	var popup_height: float = 120.0
	var general_size: float = 100.0  # Fixed size for general image
	
	_narrator_container = Control.new()
	_narrator_container.name = "NarratorContainer"
	_narrator_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_narrator_container.anchor_left = 0.0
	_narrator_container.anchor_right = 0.0
	_narrator_container.anchor_top = 1.0
	_narrator_container.anchor_bottom = 1.0
	_narrator_container.offset_left = 20
	_narrator_container.offset_top = -popup_height - 20
	_narrator_container.offset_right = popup_width + 20
	_narrator_container.offset_bottom = -20
	_narrator_container.custom_minimum_size = Vector2(popup_width, popup_height)
	_narrator_container.size = Vector2(popup_width, popup_height)
	ui_parent.add_child(_narrator_container)
	
	# Background panel
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narrator_container.add_child(panel)
	
	# HBox for general image + speech bubble
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	_narrator_container.add_child(hbox)
	
	# General sprite (TextureRect that fills the box)
	_general_sprite = TextureRect.new()
	_general_sprite.name = "GeneralSprite"
	_general_sprite.texture = GENERAL_IDLE
	_general_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_general_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_general_sprite.custom_minimum_size = Vector2(general_size, general_size)
	_general_sprite.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_general_sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_general_sprite)
	
	# Speech bubble panel
	_speech_bubble = Panel.new()
	_speech_bubble.name = "SpeechBubble"
	_speech_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speech_bubble.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_speech_bubble)
	
	# Subtitle label inside margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_speech_bubble.add_child(margin)
	
	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_subtitle_label)
	
	# Audio player - uses Voice bus for narrator speech
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioPlayer"
	_audio_player.bus = "Voice"  # All narrator audio goes through Voice bus
	_audio_player.finished.connect(_on_mumble_finished)
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
	_animate_general_mouth(delta)


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
	
	# Calculate typing speed based on audio duration or default
	var text_length = voice_line.text.length()
	if voice_line.audio:
		# Has audio - sync text typing to audio duration
		_current_audio_duration = voice_line.audio.get_length()
		if _current_audio_duration > 0 and text_length > 0:
			typing_speed = text_length / _current_audio_duration
		else:
			typing_speed = DEFAULT_CHARS_PER_SECOND
	else:
		# No audio - use default 5 chars/second
		typing_speed = DEFAULT_CHARS_PER_SECOND
		_current_audio_duration = text_length / DEFAULT_CHARS_PER_SECOND
	
	# Start typing animation
	_start_typing(voice_line.text)
	
	# Play audio - use mumbling if text exists but no audio provided
	if voice_line.audio and _audio_player:
		# Has proper voice audio
		_use_mumbling = false
		_audio_player.stream = voice_line.audio
		_audio_player.play()
	elif voice_line.text.length() > 0 and _audio_player:
		# Has text but no audio - use mumbling
		_use_mumbling = true
		_current_mumble_index = 0
		_play_next_mumble()
	elif default_rumble_audio and _audio_player:
		_use_mumbling = false
		_audio_player.stream = default_rumble_audio
		_audio_player.play()


func play_default_message(text: String, duration: float = 3.0) -> void:
	# For showing messages without predefined voice lines
	if _narrator_container:
		_narrator_container.visible = true
	
	_start_typing(text)
	
	# Use mumbling for default messages
	if _audio_player and text.length() > 0:
		_use_mumbling = true
		_current_mumble_index = 0
		_play_next_mumble()
	
	# Auto-hide after duration
	await get_tree().create_timer(duration + text.length() / typing_speed).timeout
	_stop_mumbling()
	hide_narrator()


func _play_next_mumble() -> void:
	"""Play the next mumble audio in the loop."""
	if not _audio_player or not _is_typing:
		return
	
	var mumble = MUMBLE_1 if _current_mumble_index == 0 else MUMBLE_2
	_audio_player.stream = mumble
	_audio_player.play()
	_current_mumble_index = (_current_mumble_index + 1) % 2


func _on_mumble_finished() -> void:
	"""Called when a mumble audio finishes - play next one if still typing."""
	if _use_mumbling and _is_typing:
		_play_next_mumble()


func _stop_mumbling() -> void:
	"""Stop the mumbling loop."""
	_use_mumbling = false
	if _audio_player:
		_audio_player.stop()


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
	# Stop mumbling when typing is done
	if _use_mumbling:
		_stop_mumbling()
	
	if _current_voice_line_index >= 0:
		voice_line_finished.emit(_current_voice_line_index)
		
		# Wait for cooldown then hide narrator
		await get_tree().create_timer(VOICE_LINE_COOLDOWN).timeout
		hide_narrator()
		
		# Check if all lines finished
		var all_triggered = true
		for line_data in _scheduled_lines:
			if not line_data.triggered:
				all_triggered = false
				break
		
		if all_triggered and _scheduled_lines.size() > 0:
			all_voice_lines_finished.emit()


func _animate_general_mouth(delta: float) -> void:
	if not _general_sprite:
		return
	
	# Animate general mouth: cycle through talk frames while speaking
	if _is_typing or (_audio_player and _audio_player.playing):
		# Update talk frame timer
		_talk_frame_timer += delta
		if _talk_frame_timer >= TALK_FRAME_DURATION:
			_talk_frame_timer = 0.0
			_talk_frame_index = (_talk_frame_index + 1) % 4
		
		# Set the appropriate talk texture
		match _talk_frame_index:
			0:
				_general_sprite.texture = GENERAL_TALK_1
			1:
				_general_sprite.texture = GENERAL_TALK_2
			2:
				_general_sprite.texture = GENERAL_TALK_3
			3:
				_general_sprite.texture = GENERAL_TALK_4
	else:
		# Idle - show static image
		_general_sprite.texture = GENERAL_IDLE
		_talk_frame_index = 0
		_talk_frame_timer = 0.0


func hide_narrator() -> void:
	if _narrator_container:
		_narrator_container.visible = false
	
	# Stop any mumbling
	_stop_mumbling()
	
	if _audio_player:
		_audio_player.stop()
	
	_is_typing = false
	
	# Reset general to idle
	if _general_sprite:
		_general_sprite.texture = GENERAL_IDLE


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

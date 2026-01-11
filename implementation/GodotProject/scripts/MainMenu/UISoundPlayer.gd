extends Node

@export var hover_sound: AudioStream = preload("res://assets/Audio/UI_SFX/hover.wav")
@export var click_sound: AudioStream = preload("res://assets/Audio/UI_SFX/button_click.wav")
@export var apply_accept_sound: AudioStream = preload("res://assets/Audio/UI_SFX/apply_accept.wav")
@export var apply_deny_sound: AudioStream = preload("res://assets/Audio/UI_SFX/apply_deny.wav")
@export var is_apply_button: bool = false
@export var is_apply_deny: bool = false

var _player: AudioStreamPlayer

func _ready():
	_player = AudioStreamPlayer.new()
	_player.bus = "UI"
	add_child(_player)

	if has_signal("mouse_entered"):
		connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	if has_signal("pressed"):
		connect("pressed", Callable(self, "_on_pressed"))
	if has_signal("item_selected"):
		connect("item_selected", Callable(self, "_on_item_selected"))
	if has_signal("toggled"):
		connect("toggled", Callable(self, "_on_toggled"))

func _on_mouse_entered():
	_play_sound(hover_sound)

func _on_pressed():
	if is_apply_button and not is_apply_deny:
		_play_sound(apply_accept_sound)
	elif is_apply_button and is_apply_deny:
		_play_sound(apply_deny_sound)
	else:
		_play_sound(click_sound)

func _on_item_selected(_idx):
	_play_sound(click_sound)

func _on_toggled(_on):
	_play_sound(click_sound)

func _play_sound(stream: AudioStream):
	if not stream:
		return
	_player.stop()
	_player.stream = stream
	_player.play()

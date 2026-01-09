extends Control

signal selected(item)

var scenario_data

func setup(data):
	scenario_data = data
	$Thumbnail.texture = data.scenario_thumbnail
	$Title.text = data.scenario_name
	$Description.text = data.scenario_description

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("selected", self)

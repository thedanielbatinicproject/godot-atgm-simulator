extends TextureButton

var hover_scale = Vector2(1.08, 1.08)
var normal_scale = Vector2(1, 1)
var hover_modulate = Color(0.7, 0.9, 1, 1)
var normal_modulate = Color(1, 1, 1, 1)

func _ready():
	scale = normal_scale
	modulate = normal_modulate

func _on_mouse_entered():
	get_tree().create_timer(0.01).timeout.connect(func():
		scale = hover_scale
		modulate = hover_modulate)

func _on_mouse_exited():
	get_tree().create_timer(0.01).timeout.connect(func():
		scale = normal_scale
		modulate = normal_modulate)

func _gui_input(event):
	if event is InputEventMouseMotion:
		if get_rect().has_point(event.position):
			_on_mouse_entered()
		else:
			_on_mouse_exited()

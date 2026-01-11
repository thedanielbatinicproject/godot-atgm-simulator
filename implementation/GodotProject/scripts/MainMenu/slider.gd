extends HSlider

@export var audio_bus_name: String
var audio_bus_id
@onready var music_slider: HSlider = $"."
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_value_changed(value: float) -> void:
	var db = lerp(-50, 10, value / 100.0)
	AudioServer.set_bus_volume_db(audio_bus_id, db)

extends Node3D
class_name Projectile

@export var rocket_data: Resource # Use Resource as a generic type if RocketData is a custom resource

var state = StateVariables.new()
var forces = Forces.new()
var moments = Moments.new()
var guidance = Guidance.new()
var environment = ModelEnvironment.new() # tvoja nova klasa
var utils = Utils.new()

func _ready():
	if rocket_data:
		print("Launching rocket: ", rocket_data.name)
	else:
		print("No RocketData assigned!")

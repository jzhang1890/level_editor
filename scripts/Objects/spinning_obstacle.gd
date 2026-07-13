extends Obstacle
class_name SpinningObstacle

@export var spin_speed: float = 180.0 # Degrees per second
var start_rotation: float = 0.0

func _ready() -> void:
	# Capture the exact rotation you set in the editor
	start_rotation = get_meta("base_rotation", rotation_degrees)

func _process(_delta: float) -> void:
	# Get the exact time the game has been running in seconds
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Read the meta dynamically so editor Nudges update it instantly 
	var current_base = get_meta("base_rotation", start_rotation)
	
	# Calculate the exact deterministic rotation
	$Sprite2D.rotation_degrees = current_base + (current_time * spin_speed)

extends Sprite2D

# Exporting it lets you change the speed in the Inspector for different objects!
# 360.0 means it does one full rotation every second. 
# Use a negative number to spin counter-clockwise.
@export var spin_speed: float = 360.0
var start_rotation: float = 0.0

func _process(_delta: float) -> void:
	# Get the exact time the game has been running in seconds
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Calculate the exact deterministic rotation
	rotation_degrees = start_rotation + (current_time * spin_speed)

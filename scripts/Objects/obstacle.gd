# Saved as Obstacle.gd
extends StaticBody2D
class_name Obstacle

# Turns the green selection tint on/off
func set_highlight(active: bool) -> void:
	if active:
		modulate = Color(0.5, 1.5, 0.5) # Green highlight
	else:
		modulate = Color.WHITE # Reset to normal

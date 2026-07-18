extends StaticBody2D
class_name Obstacle

var base_position: Vector2

func _ready() -> void:
	# Anchor the starting position the moment the level loads
	base_position = global_position

func reset() -> void:
	global_position = base_position

# Turns the green selection tint on/off
func set_highlight(active: bool) -> void:
	if active:
		modulate = Color(0.5, 1.5, 0.5) 
	else:
		var current_channel = get_meta("color_channel", 0)
		
		# We don't need to do any math here anymore. 
		# Global handles the checking and the fallback automatically!
		modulate = Global.get_channel_color(current_channel)

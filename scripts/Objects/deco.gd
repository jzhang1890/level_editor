extends Sprite2D
class_name Deco

var base_position: Vector2

func _ready() -> void:
	# Anchor the starting position the moment the level loads
	base_position = global_position

func reset() -> void:
	global_position = base_position

# Turns the green selection tint on/off
func set_highlight(active: bool) -> void:
	if active:
		modulate = Color(0.5, 1.5, 0.5) # Green highlight
	else:
		modulate = Color.WHITE # Reset to normal

extends Camera2D

@export var pan_speed: float = 1.0
@export var scroll_speed: float = 30.0

func _unhandled_input(event: InputEvent) -> void:
	# 1. PANNING: Move camera if holding mouse button
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		
		# Pans the camera
		position -= event.relative * pan_speed / zoom.x
		
		# Fixing the bug where camera gets stuck at edge
		# Force Godot to calculate the camera's visual limits
		force_update_scroll()
		
		# Snap the actual node to the clamped visual center so it can't wander off
		global_position = get_screen_center_position()

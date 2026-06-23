extends Camera2D

@export var pan_speed: float = 1.0
@export var scroll_speed: float = 30.0

func _unhandled_input(event: InputEvent) -> void:
	# 1. PANNING: Move freely anywhere if holding Middle Mouse Button
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Moving the camera opposite to mouse drag creates a natural "hand pan" tool feel
		position -= event.relative * pan_speed / zoom.x

	# 2. VERTICAL SCROLLING: Scroll wheel moves the view up/down
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position.y -= scroll_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position.y += scroll_speed

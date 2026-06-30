extends Node2D

@onready var ui_layer: CanvasLayer = $EditorUI
@onready var room_canvas: Node2D = $Foreground/RoomCanvas

# The camera
@onready var camera: Camera2D = $Camera2D 

# Tracking for drag vs click
var mouse_down_screen_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_threshold: float = 10.0 

# Tracking for selection
var selected_world_object: CollisionObject2D = null 

const GRID_SIZE: float = 64.0 # Set this to match your block sprite sizes (e.g., 30, 60)

# Zoom settings
var min_zoom: float = 0.5  # How far out you can see
var max_zoom: float = 3.0  # How close you can zoom in
var zoom_step: float = 0.2 # How much the buttons zoom per click

func _unhandled_input(event: InputEvent) -> void:

	# Zoom by scrolling
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			apply_zoom_at_mouse(camera.zoom.x + zoom_step/5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			apply_zoom_at_mouse(camera.zoom.x - zoom_step/5)

	# 1. Track dragging to protect your camera panning
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if event.position.distance_to(mouse_down_screen_pos) > drag_threshold:
			is_dragging = true

	# 2. Handle Mouse Clicks
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_down_screen_pos = event.position
			is_dragging = false 
			
		elif not event.pressed:
			if not is_dragging:
				var click_pos = get_global_mouse_position()
				var clicked_obj = check_for_object_at(click_pos)
				
				if clicked_obj != null:
					change_selection(clicked_obj)
				else:
					if ui_layer.selected_scene_path != "":
						change_selection(null) 
						place_object(click_pos)
			
			is_dragging = false


# Zoom logic
func apply_zoom(target_zoom: float) -> void:
	# Keeps zoom within min and max zoom limit by clamping it between the limits
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)
	
	# Apply the new zoom equally to both X and Y axes
	camera.zoom = Vector2(target_zoom, target_zoom)
	
	# Tell the canvas to update the grid thickness
	room_canvas.queue_redraw()

func apply_zoom_at_mouse(requested_zoom: float) -> void:
	var old_zoom = camera.zoom.x

	# Keeps zoom within min and max zoom limit by clamping it between the limits
	var new_zoom = clamp(requested_zoom, min_zoom, max_zoom)
	
	# If already at the zoom limit, do nothing
	if old_zoom == new_zoom:
		return
		
	# 1. Calculate the shift
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_center = get_viewport_rect().size / 2.0
	var mouse_offset = mouse_pos - screen_center
	var shift = mouse_offset * (1.0 / old_zoom - 1.0 / new_zoom)
	
	# 2. Move the camera
	camera.global_position += shift
	
	# 3. Existing zoom function
	apply_zoom(new_zoom)

# Zoom buttons
func _on_zoom_in_button_pressed() -> void:
	# Add the step to our current zoom
	apply_zoom(camera.zoom.x + zoom_step)

func _on_zoom_out_button_pressed() -> void:
	# Subtract the step from our current zoom
	apply_zoom(camera.zoom.x - zoom_step)
	

# Selection logic
func check_for_object_at(pos: Vector2) -> CollisionObject2D:
	# Use Godot's physics engine to poke the screen and see what's under the mouse
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_bodies = true # Finds StaticBody2D
	query.collide_with_areas = true  # Finds Area2D
	
	var results = space_state.intersect_point(query)
	
	if results.size() > 0:
		# Return the object we touched
		return results[0]["collider"] as CollisionObject2D
	return null

func change_selection(new_object: CollisionObject2D) -> void:
	# 1. Turn off the green highlight on the old object
	if selected_world_object != null and is_instance_valid(selected_world_object):
		if selected_world_object.has_method("set_highlight"):
			selected_world_object.set_highlight(false)
			
	# 2. Update tracking variable
	selected_world_object = new_object
	
	# 3. Turn on the green highlight on the new object
	if selected_world_object != null:
		if selected_world_object.has_method("set_highlight"):
			selected_world_object.set_highlight(true)

# Placement logic
func place_object(pos: Vector2) -> void:
	var object_resource = load(ui_layer.selected_scene_path)
	if object_resource:
		var new_object = object_resource.instantiate()
		
		var cell_x = floor(pos.x / GRID_SIZE)
		var cell_y = floor(pos.y / GRID_SIZE)
		
		# Multiply back up to world coordinates, then add half the grid size (32) 
		# so the center-anchored object sits exactly in the middle of the box.
		var snapped_x = (cell_x * GRID_SIZE) + (GRID_SIZE / 2.0)
		var snapped_y = (cell_y * GRID_SIZE) + (GRID_SIZE / 2.0)
		
		new_object.global_position = Vector2(snapped_x, snapped_y)
		
		room_canvas.add_child(new_object)

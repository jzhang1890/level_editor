extends Node2D

@onready var ui_layer: CanvasLayer = $EditorUI
@onready var room_canvas: Node2D = $Foreground/RoomCanvas

# Tracking for drag vs click
var mouse_down_screen_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_threshold: float = 10.0 

# Tracking for selection
var selected_world_object: CollisionObject2D = null 

const GRID_SIZE: float = 64.0 # Set this to match your block sprite sizes (e.g., 30, 60)

func _unhandled_input(event: InputEvent) -> void:
	
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
				# --- IT WAS A CLEAN CLICK ---
				var click_pos = get_global_mouse_position()
				
				# Check if we clicked an existing object first
				var clicked_obj = check_for_object_at(click_pos)
				
				if clicked_obj != null:
					# Select the object!
					change_selection(clicked_obj)
				else:
					# Clicked empty space. Place a new object if armed!
					if ui_layer.selected_scene_path != "":
						# Deselect whatever we were holding
						change_selection(null) 
						place_object(click_pos)
			
			is_dragging = false

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
	# 1. Turn off the green highlight on the OLD object
	if selected_world_object != null and is_instance_valid(selected_world_object):
		if selected_world_object.has_method("set_highlight"):
			selected_world_object.set_highlight(false)
			
	# 2. Update our tracking variable
	selected_world_object = new_object
	
	# 3. Turn ON the green highlight on the NEW object
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
		
		# 2. Multiply back up to world coordinates, then add half the grid size (32) 
		# so the center-anchored object sits exactly in the middle of the box.
		var snapped_x = (cell_x * GRID_SIZE) + (GRID_SIZE / 2.0)
		var snapped_y = (cell_y * GRID_SIZE) + (GRID_SIZE / 2.0)
		
		new_object.global_position = Vector2(snapped_x, snapped_y)
		
		room_canvas.add_child(new_object)

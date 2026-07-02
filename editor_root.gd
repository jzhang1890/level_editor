extends Node2D

@onready var ui_layer: CanvasLayer = $EditorUI
@onready var room_canvas: Node2D = $Foreground/RoomCanvas

@onready var camera: Camera2D = $Camera2D 

# Grab the container instead of the individual button
@onready var selection_menu: Control = $EditorUI/SelectionMenu

# Grab the TextureRect node from Parallax Background setup
@onready var bg_rect: TextureRect = $BackgroundCanvas/BackgroundLayer/Background

# Pause Menu references
@onready var pause_menu: ColorRect = $EditorUI/PauseMenu
@onready var level_name_label: Label = $EditorUI/PauseMenu/LevelNameLabel

# Default background path
var current_bg_path: String = "res://Sprites/Backgrounds/background1.png"

# Tracking for drag vs click
var mouse_down_screen_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_threshold: float = 10.0 

# Tracking for selection
var selected_world_object: CollisionObject2D = null 

# Save path
var current_save_path: String = "user://Levels/my_new_level.json"

var current_level_name: String = "My Custom Level"

const GRID_SIZE: float = 64.0

# Zoom settings
var min_zoom: float = 0.5  # How far out you can see
var max_zoom: float = 3.0  # How close you can zoom in
var zoom_step: float = 0.2 # How much the buttons zoom per click

var paused = false

func _ready() -> void:
	
	# Hide the entire contextual menu at the start
	if selection_menu:
		selection_menu.visible = false
	if pause_menu:
		pause_menu.visible = false
	
	# If the global script has a level queued up, load it immediately
	if Global.level_to_load != "":
		current_save_path = Global.level_to_load # Ensure we save over this exact file later
		load_level(current_save_path)
		
		# Clear the global variable so it doesn't accidentally load again next time
		Global.level_to_load = ""

func _unhandled_input(event: InputEvent) -> void:

	if not paused:
	# Backspace for deletion
		if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
			delete_selected_object()
			return # Stop processing this event

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
	# Pokes the screen and see what's under the mouse
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

# Change selected object
func change_selection(new_object: CollisionObject2D) -> void:
	# 1. Turn off the green highlight on the OLD object
	if selected_world_object != null and is_instance_valid(selected_world_object):
		if selected_world_object.has_method("set_highlight"):
			selected_world_object.set_highlight(false)
			
	# 2. Update our tracking variable
	selected_world_object = new_object
	
	# 3. Turn ON the green highlight on the NEW object, and SHOW/HIDE the UI menu
	if selected_world_object != null:
		if selected_world_object.has_method("set_highlight"):
			selected_world_object.set_highlight(true)
		
		# Show the entire contextual menu because we selected something
		if selection_menu:
			selection_menu.visible = true
	else:
		# Hide the entire contextual menu because we clicked empty space
		if selection_menu:
			selection_menu.visible = false

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

# Deletion logic
func delete_selected_object() -> void:
	# Make sure we actually have something selected before trying to delete
	if selected_world_object != null and is_instance_valid(selected_world_object):
		# Remove the object from the game completely
		selected_world_object.queue_free()
		
		# Reset selection back to null (which also hides the button)
		change_selection(null)

func _on_delete_button_pressed() -> void:
	delete_selected_object()

# Save and Load Logic

# Saving Level function
func _on_save_button_pressed() -> void:
	if not DirAccess.dir_exists_absolute("user://Levels"):
		DirAccess.make_dir_absolute("user://Levels")

	var items_array: Array = []
	
	for child in room_canvas.get_children():
		if child.scene_file_path != "":
			var item_data = {
				"scene_path": child.scene_file_path,
				"x": child.global_position.x,
				"y": child.global_position.y
			}
			items_array.append(item_data)
			
	# Wraps everything into a dictionary
	var save_dict: Dictionary = {
		"level_name": current_level_name,
		"background": current_bg_path, 
		"items": items_array
	}
			
	var file = FileAccess.open(current_save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_dict, "\t") 
		file.store_string(json_string)
		file.close()
		print("Level saved to: ", current_save_path)

# Loading level function
func load_level(target_path: String) -> void:
	if not FileAccess.file_exists(target_path):
		print("No save file found at: ", target_path)
		return
		
	change_selection(null)
	
	for child in room_canvas.get_children():
		child.queue_free()
		
	var file = FileAccess.open(target_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var level_data = JSON.parse_string(json_string)
		
		# Check if the data is the Dictionary format
		if typeof(level_data) == TYPE_DICTIONARY and level_data.has("items"):
			
			# Grab the name to update the variable
			if level_data.has("level_name"):
				current_level_name = level_data["level_name"]
				print("Loading level: ", current_level_name)
			
			# Load and apply the background
			if level_data.has("background"):
				current_bg_path = level_data["background"]
				var loaded_texture = load(current_bg_path)
				
				# Add this line to actually apply the texture to the screen!
				if loaded_texture:
					bg_rect.texture = loaded_texture
			
			# Loop through the items array tucked inside the dictionary
			for item in level_data["items"]:
				var resource = load(item["scene_path"])
				if resource:
					var new_object = resource.instantiate()
					new_object.global_position = Vector2(item["x"], item["y"])
					room_canvas.add_child(new_object)
					
# Call this from UI when the user picks a new background
func change_background(new_path: String) -> void:
	var new_texture = load(new_path)
	if new_texture:
		bg_rect.texture = new_texture
		current_bg_path = new_path # Update the variable so it saves correctly later


# Pause Menu logic

func _on_pause_button_pressed() -> void:
	# Update the label to show the name of the level
	if level_name_label:
		level_name_label.text = current_level_name
		
	# Reveal the menu
	if pause_menu:
		pause_menu.visible = true
	paused = true

func _on_resume_button_pressed() -> void:
	# Hide the menu to go back to editing
	if pause_menu:
		pause_menu.visible = false
	paused = false

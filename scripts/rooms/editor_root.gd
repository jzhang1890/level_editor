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

# Tab container reference
@onready var main_tab_container: TabContainer = $EditorUI/EditorPanel/MainTabContainer

# Layer label in LayerContainer 
@onready var layer_label: Label = $EditorUI/LayerContainer/LayerLabel

# 0 represents the "All" layer, 0 is the starting layer
var current_layer: int = 0
var max_layer: int = 1

# Editor modes
enum EditorMode { BUILD, EDIT, DELETE }
# On build tab at start
var current_mode: EditorMode = EditorMode.BUILD

# Default background path
var current_bg_path: String = "res://Sprites/Backgrounds/background1.png"

# Tracking for drag vs click
var mouse_down_screen_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_threshold: float = 25.0 

# Track for dragging object
var is_dragging_objects: bool = false
var previous_mouse_pos: Vector2 = Vector2.ZERO

# Tracking for selection
var selected_objects: Array[CollisionObject2D] = []

# Clipboard for Copy/Paste 
var clipboard: Array[Dictionary] = []

# Save path
var current_save_path: String = "user://Levels/my_new_level.json"

var current_level_name: String = "Untitled"

const GRID_SIZE: float = 64.0

# Zoom settings
var min_zoom: float = 0.3  # How far out you can see
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
		current_save_path = Global.level_to_load # Makes sure to save to this file later
		load_level(current_save_path)

func _unhandled_input(event: InputEvent) -> void:

	if not paused:
	# Backspace for deletion
		if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
			delete_selected_object()
			return # Stop processing this event

		# --- NEW: Copy (Ctrl + C) ---
		if event is InputEventKey and event.pressed and event.keycode == KEY_C and Input.is_key_pressed(KEY_CTRL):
			copy_selection()
			return
			
		# --- NEW: Paste (Ctrl + V) ---
		if event is InputEventKey and event.pressed and event.keycode == KEY_V and Input.is_key_pressed(KEY_CTRL):
			paste_clipboard()
			return

		# Zoom by scrolling
		if event is InputEventMouseButton and event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				apply_zoom_at_mouse(camera.zoom.x + zoom_step/5)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				apply_zoom_at_mouse(camera.zoom.x - zoom_step/5)

		# 1. Track dragging to protect camera panning
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if is_dragging_objects:
				var current_mouse_pos = get_global_mouse_position()
				var mouse_delta = current_mouse_pos - previous_mouse_pos
				
				for obj in selected_objects:
					if is_instance_valid(obj):
						obj.global_position += mouse_delta
						
				previous_mouse_pos = current_mouse_pos
				
				# --- NEW: Kill the input so the camera script never sees it ---
				get_viewport().set_input_as_handled() 
				return # Stop processing in this script
			
			if event.position.distance_to(mouse_down_screen_pos) > drag_threshold:
				is_dragging = true

		# 2. Handle Mouse Clicks
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_down_screen_pos = event.position
				is_dragging = false 
				
				# Check if we are grabbing a selected object 
				if current_mode == EditorMode.EDIT:
					var click_pos = get_global_mouse_position()
					var clicked_obj = check_for_object_at(click_pos)
					
					# If user clicked something that's already selected, grab it.
					if clicked_obj != null and selected_objects.has(clicked_obj):
						is_dragging_objects = true
						previous_mouse_pos = click_pos
						
						# Freeze the camera so it cannot steal the input
						camera.set_process_unhandled_input(false)
						camera.set_process_input(false)
						camera.set_process(false)
						
						# Kill the input so the camera script never sees the initial click
						get_viewport().set_input_as_handled()
						return # Stop processing the click so it doesn't deselect
				
			# The user let go of event
			elif not event.pressed:
				# Drop the objects
				if is_dragging_objects:
					is_dragging_objects = false
					
					# Unfreeze the camera
					camera.set_process_unhandled_input(true)
					camera.set_process_input(true)
					camera.set_process(true)
					
					# Kill the input so dropping doesn't trigger random camera jumps 
					get_viewport().set_input_as_handled()
					return
				
				# Not dragging so it's a click
				if not is_dragging:
					var click_pos = get_global_mouse_position()
					var clicked_obj = check_for_object_at(click_pos)
					
					# Mode-based click logic
					match current_mode:
						EditorMode.BUILD:
							# Only place objects. Ignore selections.
							if ui_layer.selected_scene_path != "":
								place_object(click_pos)
								
						EditorMode.EDIT:
							# Check if Ctrl is held down for multi-select
							var is_multi = Input.is_key_pressed(KEY_CTRL)
							
							# Pass both the object and the multi-select status
							change_selection(clicked_obj, is_multi)
							
						EditorMode.DELETE:
							# Instantly delete whatever is clicked.
							if clicked_obj != null:
								clicked_obj.queue_free()
				
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
	var new_zoom = clamp(requested_zoom, min_zoom, max_zoom)
	
	if is_equal_approx(old_zoom, new_zoom):
		return
		
	# 1. Get the distance between the camera's center and the mouse
	var mouse_world_pos = get_global_mouse_position()
	var offset_to_mouse = mouse_world_pos - camera.global_position
	
	# 2. Calculate how much the world shrinks/grows relative to the mouse
	var shift = offset_to_mouse * (1.0 - (old_zoom / new_zoom))
	
	# 3. Shift the camera to instantly compensate
	camera.global_position += shift
	
	# 4. Apply the actual zoom
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
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	var results = space_state.intersect_point(query)
	
	var best_object: CollisionObject2D = null
	var best_z_index: int = -999999
	var best_tree_index: int = -1
	
	# Filter through all clicked objects to find the top-most one
	for result in results:
		var collider = result["collider"] as CollisionObject2D
		if collider:
			var obj_layer = collider.get_meta("layer", 1)
			
			# Check if the object is on the active layer
			if current_layer == 0 or current_layer == obj_layer:
				
				# 1. Compare Z-Index (Layer depth)
				if collider.z_index > best_z_index:
					best_object = collider
					best_z_index = collider.z_index
					best_tree_index = collider.get_index()
					
				# 2. Tie breaker: If they are on the exact same layer, pick the one drawn last
				elif collider.z_index == best_z_index:
					if collider.get_index() > best_tree_index:
						best_object = collider
						best_tree_index = collider.get_index()
						
	# Returns the absolute top-most object, or null if nothing was clicked
	return best_object

# Change selected object
func change_selection(clicked_obj: CollisionObject2D, is_multi: bool = false) -> void:
	# 1. If the user is not holding Ctrl, clear everything first
	if not is_multi:
		for obj in selected_objects:
			if is_instance_valid(obj) and obj.has_method("set_highlight"):
				obj.set_highlight(false)
		selected_objects.clear()
		
	# 2. If user clicked an actual object
	if clicked_obj != null:
		if is_multi and selected_objects.has(clicked_obj):
			# OFF toggle: If user Ctrl+Clicked an object already in the group, remove it
			selected_objects.erase(clicked_obj)
			if clicked_obj.has_method("set_highlight"):
				clicked_obj.set_highlight(false)
		else:
			# Toggle ON: Add to group and highlight
			if not selected_objects.has(clicked_obj):
				selected_objects.append(clicked_obj)
			if clicked_obj.has_method("set_highlight"):
				clicked_obj.set_highlight(true)
				
	# 3. Show the UI menu if at least one object is selected
	if selection_menu:
		selection_menu.visible = selected_objects.size() > 0

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
		
		# Generate a unique id string using the exact microsecond the object was placed
		var unique_id = str(Time.get_ticks_usec()) + str(randi() % 1000)
		new_object.set_meta("unique_id", unique_id)
		
		# Sets the base rotation to 0
		new_object.set_meta("base_rotation", 0.0)
		
		# Sets the layer of the new object
		var assigned_layer = current_layer
		if assigned_layer == 0:
			assigned_layer = 1
			
		new_object.set_meta("layer", assigned_layer)
		
		# Set the z-index so the object is behind objects of higher layers
		new_object.z_index = -assigned_layer
		
		room_canvas.add_child(new_object)

# Deletion logic
func delete_selected_object() -> void:
	# Loop through all selected objects and delete them
	for obj in selected_objects:
		if is_instance_valid(obj):
			obj.queue_free()
			
	# Passing null without Ctrl pressed automatically clears the array and hides the menu
	change_selection(null)

func _on_delete_button_pressed() -> void:
	delete_selected_object()

# Load Logic

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
				if loaded_texture:
					bg_rect.texture = loaded_texture
			
			# Loop through the items array tucked inside the dictionary
			for item in level_data["items"]:
				var resource = load(item["scene_path"])
				if resource:
					var new_object = resource.instantiate()
					# Position of object
					new_object.global_position = Vector2(item["x"], item["y"])
					
					# Apply rotation (defaults to 0.0)
					var loaded_rot = item.get("rotation", 0.0)
					new_object.rotation_degrees = loaded_rot
					
					# Save that rotation into the metadata
					new_object.set_meta("base_rotation", loaded_rot)
					
					# Apply scale (defaults to 1.0)
					var s_x = item.get("scale_x", 1.0)
					var s_y = item.get("scale_y", 1.0)
					new_object.scale = Vector2(s_x, s_y)
					
					# Apply the saved ID, or create a new one if it's missing
					var loaded_id = item.get("id", str(Time.get_ticks_usec()))
					new_object.set_meta("unique_id", loaded_id)
					
					# Load the layer data and apply it
					var loaded_layer = item.get("layer", 1)
					new_object.set_meta("layer", loaded_layer)
					
					# Z-index so the object is behind objects of higher layers
					new_object.z_index = -loaded_layer
					
					# Expand the max_layer limit so the right arrow button knows how far to go
					if loaded_layer > max_layer:
						max_layer = loaded_layer
					
					room_canvas.add_child(new_object)
					
# Called when the user picks a new background
func change_background(new_path: String) -> void:
	var new_texture = load(new_path)
	if new_texture:
		bg_rect.texture = new_texture
		current_bg_path = new_path # Update the variable so it saves correctly later

# Tab switching logic
func _on_main_tab_container_tab_changed(tab: int) -> void:
	# 0 = Build, 1 = Edit, 2 = Delete
	current_mode = tab as EditorMode

# Pause Menu logic
func _on_pause_button_pressed() -> void:
	# Shows name of level
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
				"y": child.global_position.y,
				"rotation": child.get_meta("base_rotation", child.rotation_degrees),
				"scale_x": child.scale.x,
				"scale_y": child.scale.y,
				"id": child.get_meta("unique_id") if child.has_meta("unique_id") else str(randi()),
				"layer": child.get_meta("layer", 1),
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
	
func _on_save_and_quit_button_pressed() -> void:
	# Just combines save and quit logic
	_on_save_button_pressed()
	_on_quit_button_pressed()
	
func _on_quit_button_pressed() -> void:
	# Return to Level Browser scene
	get_tree().change_scene_to_file("res://scenes/rooms/level_details.tscn")
	
func _on_editor_ui_edit_action_requested(action_name: String) -> void:
	# Make sure the array isn't empty before performing edit action
	if selected_objects.is_empty():
		return
				
	# --- NEW: Find the center of the group ---
	var group_center: Vector2 = Vector2.ZERO
	for obj in selected_objects:
		group_center += obj.global_position
	group_center /= selected_objects.size()	
		
	# Loop through every object currently selected
	for obj in selected_objects:
		if not is_instance_valid(obj):
			continue
			
		# Apply transformation to the current 'obj' in the loop
		match action_name:
			"move_up_tiny":
				obj.global_position.y -= GRID_SIZE/16
			"move_down_tiny":
				obj.global_position.y += GRID_SIZE/16
			"move_left_tiny":
				obj.global_position.x -= GRID_SIZE/16
			"move_right_tiny":
				obj.global_position.x += GRID_SIZE/16
			"rotate_left":
				# 1. Rotate the object itself 
				var new_rot = obj.get_meta("base_rotation", obj.rotation_degrees) - 15
				obj.set_meta("base_rotation", new_rot)
				obj.rotation_degrees = new_rot
				
				# 2. Orbit the position around the group center
				var offset = obj.global_position - group_center
				
				# Godot's rotated() function requires radians, so convert -90 degrees
				var rotated_offset = offset.rotated(deg_to_rad(-15))
				
				# Apply the new offset to the center point
				obj.global_position = group_center + rotated_offset
			
			"rotate_right":
				# 1. Rotate the object itself 
				var new_rot = obj.get_meta("base_rotation", obj.rotation_degrees) + 15
				obj.set_meta("base_rotation", new_rot)
				obj.rotation_degrees = new_rot
				
				# 2. Orbit the position around the group center
				var offset = obj.global_position - group_center
				
				# Godot's rotated() function requires radians, so convert 90 degrees
				var rotated_offset = offset.rotated(deg_to_rad(15))
				
				# Apply the new offset to the center point
				obj.global_position = group_center + rotated_offset


func _on_left_arrow_button_pressed() -> void:
	# Deselects objects when changing layers
	change_selection(null, false)
	
	if current_layer > 0:
		current_layer -= 1
	update_layer_display()

func _on_right_arrow_button_pressed() -> void:
	# Deselects objects when changing layers
	change_selection(null, false)
	
	current_layer += 1
	# Expand the layer is pushed passed limit
	if current_layer > max_layer:
		max_layer = current_layer
	update_layer_display()

func update_layer_display() -> void:
	if current_layer == 0:
		layer_label.text = "All"
	else:
		layer_label.text = str(current_layer)
		
	# Instantly refresh the screen transparency when the layer changes
	refresh_layer_visibility()
	
func refresh_layer_visibility() -> void:
	for child in room_canvas.get_children():
		# Grab the sticky note. Fallback to layer 1 for older objects.
		var obj_layer = child.get_meta("layer", 1)
		
		if current_layer == 0 or current_layer == obj_layer:
			child.modulate.a = 1.0  # Fully opaque
		else:
			child.modulate.a = 0.2 # Transparent

# --- COPY AND PASTE LOGIC ---

func copy_selection() -> void:
	# Clear the old clipboard
	clipboard.clear()
	
	# Save the exact state of every selected object
	for obj in selected_objects:
		if is_instance_valid(obj) and obj.scene_file_path != "":
			var item_data = {
				"scene_path": obj.scene_file_path,
				"global_position": obj.global_position,
				"rotation_degrees": obj.rotation_degrees,
				"base_rotation": obj.get_meta("base_rotation", obj.rotation_degrees),
				"scale": obj.scale,
				"layer": obj.get_meta("layer", 1)
			}
			clipboard.append(item_data)

func paste_clipboard() -> void:
	if clipboard.is_empty():
		return
		
	# 1. Drop the currently selected objects
	change_selection(null, false)
	
	var new_selection: Array[CollisionObject2D] = []
	
	# 2. Build the new objects from the clipboard data
	for item in clipboard:
		var resource = load(item["scene_path"])
		if resource:
			var new_object = resource.instantiate()
			
			# Offset the position by 1 grid blocks up
			var new_pos = item["global_position"] + Vector2(0, GRID_SIZE * -1)
			new_object.global_position = new_pos
			
			# Apply visual transforms
			new_object.rotation_degrees = item["rotation_degrees"]
			new_object.scale = item["scale"]
			
			# Apply metadata and depth sorting
			new_object.set_meta("base_rotation", item["base_rotation"])
			new_object.set_meta("layer", item["layer"])
			new_object.z_index = -item["layer"]
			
			# Generate a brand new unique ID for the clone
			var unique_id = str(Time.get_ticks_usec()) + str(randi() % 1000)
			new_object.set_meta("unique_id", unique_id)
			
			room_canvas.add_child(new_object)
			new_selection.append(new_object)
			
			# UPDATE the clipboard item's position so pasting again moves it another 2 blocks!
			item["global_position"] = new_pos
			
	# 3. Automatically select the newly pasted objects
	for obj in new_selection:
		# Passing 'true' simulates holding Ctrl, adding them all to the group
		change_selection(obj, true)

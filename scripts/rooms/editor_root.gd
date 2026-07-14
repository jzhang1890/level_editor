extends Node2D

# The UI with tabs
@onready var ui_layer: CanvasLayer = $EditorUI

# The room where you put the objects
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

@onready var scrollbar: VSlider = $EditorUI/VSlider

# Threading variables
var save_thread: Thread

# Chunking variables
const CHUNK_HEIGHT: float = 256.0
var level_chunks: Dictionary = {}
var active_chunks: Array = []
var last_calculated_chunk: int = -999

# 0 represents the "All" layer, 0 is the starting layer
var current_layer: int = 0
var max_layer: int = 1

# Editor modes
enum EditorMode { BUILD, EDIT, DELETE }
# On build tab at start
var current_mode: EditorMode = EditorMode.BUILD

# Default background path
var current_bg_path: String = "res://Resources/Backgrounds/background1.png"

# Tracking for drag vs click
var mouse_down_screen_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_threshold: float = 25.0

# Track for dragging object
var is_dragging_objects: bool = false
var previous_mouse_pos: Vector2 = Vector2.ZERO

# Tracking for Box Selection 
var is_box_selecting: bool = false
var mouse_down_world_pos: Vector2 = Vector2.ZERO
var box_current_pos: Vector2 = Vector2.ZERO

# Tracking for selection
var selected_objects: Array[CollisionObject2D] = []

# Clipboard for Copy/Paste 
var clipboard: Array[Dictionary] = []

# Undo/Redo variables
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
const MAX_UNDO_STEPS: int = 100
var drag_start_state: Array = []

# Save path
var current_save_path: String = "user://Levels/my_new_level.json"

# Gives it untitled if it doesnt have a name
var current_level_name: String = "Untitled"

# Current size of one grid
const GRID_SIZE: float = 64.0

# Zoom settings
var min_zoom: float = 0.35  # How far out you can see
var max_zoom: float = 3.0  # How close you can zoom in
var zoom_step: float = 0.2 # How much the buttons zoom per click

# Game state
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
		
func _exit_tree() -> void:
	# This intercepts the scene closure and forces the engine 
	# to wait for the background thread to safely finish saving.
	if save_thread and save_thread.is_started():
		save_thread.wait_to_finish()

func _unhandled_input(event: InputEvent) -> void:
	if not paused:
	# Backspace for deletion
		if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
			delete_selected_object()
			return # Stop processing this event

		# Copy (Ctrl + C)
		if event is InputEventKey and event.pressed and event.keycode == KEY_C and Input.is_key_pressed(KEY_CTRL):
			copy_selection()
			return
			
		# Paste (Ctrl + V) 
		if event is InputEventKey and event.pressed and event.keycode == KEY_V and Input.is_key_pressed(KEY_CTRL):
			paste_clipboard()
			return
			
		# Undo (Ctrl + Z)
		if event is InputEventKey and event.pressed and event.keycode == KEY_Z and Input.is_key_pressed(KEY_CTRL):
			undo_action()
			return
			
		# Redo (Ctrl + Y)
		if event is InputEventKey and event.pressed and event.keycode == KEY_Y and Input.is_key_pressed(KEY_CTRL):
			redo_action()
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
				
				# Kill the input so the camera script never sees it 
				get_viewport().set_input_as_handled()
				
				# Tell the gizmo to follow the newly moved objects
				if has_node("Foreground/TransformGizmo"):
					$Foreground/TransformGizmo._calculate_bounding_box()
					
				return # Stop processing in this script
				
			# Box Selection Dragging 
			if current_mode == EditorMode.EDIT and Input.is_key_pressed(KEY_CTRL):
				if event.position.distance_to(mouse_down_screen_pos) > drag_threshold:
					is_box_selecting = true
					box_current_pos = get_global_mouse_position()
					
					# Freeze the camera while drawing the box
					camera.set_process_unhandled_input(false)
					camera.set_process_input(false)
					camera.set_process(false)
					
					queue_redraw() # Tells the engine to update our drawn rectangle
					get_viewport().set_input_as_handled()
					return
				
			if event.position.distance_to(mouse_down_screen_pos) > drag_threshold:
				is_dragging = true

		# 2. Handle Mouse Clicks
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_down_screen_pos = event.position
				mouse_down_world_pos = get_global_mouse_position() # Anchor the starting corner for rectangle selection
				is_dragging = false
				
				# --- FIX A: Freeze camera instantly if preparing to draw a box ---
				if current_mode == EditorMode.EDIT and Input.is_key_pressed(KEY_CTRL):
					camera.set_process_unhandled_input(false)
					camera.set_process_input(false)
					camera.set_process(false)
				
				# Check if we are grabbing a selected object 
				if current_mode == EditorMode.EDIT:
					var click_pos = get_global_mouse_position()
					var clicked_obj = check_for_object_at(click_pos)
					
					# If user clicked something that's already selected, grab it.
					if clicked_obj != null and selected_objects.has(clicked_obj):
						is_dragging_objects = true
						previous_mouse_pos = click_pos
						
						# Snapshot state before drag begins
						drag_start_state = serialize_objects(selected_objects)
						
						# Freeze the camera so it cannot steal the input
						camera.set_process_unhandled_input(false)
						camera.set_process_input(false)
						camera.set_process(false)
						
						# Kill the input so the camera script never sees the initial click
						get_viewport().set_input_as_handled()
						return # Stop processing the click so it doesn't deselect
				
			# The user let go of event
			elif not event.pressed:
				
				# --- FIX B: Unconditionally unfreeze the camera on release ---
				camera.set_process_unhandled_input(true)
				camera.set_process_input(true)
				camera.set_process(true)
				
				# Drop the objects
				if is_dragging_objects:
					is_dragging_objects = false
					
					# Ending of the dragging object state
					var drag_end_state = serialize_objects(selected_objects)
					commit_action("edit", drag_start_state, drag_end_state)
					
					# Kill the input so dropping doesn't trigger random camera jumps 
					get_viewport().set_input_as_handled()
					return
				
				# Finish Box Selection 
				if is_box_selecting:
					is_box_selecting = false
					
					queue_redraw() # Erases the blue box from the screen
					
					# Calculate what objects were inside the box
					perform_box_selection(mouse_down_world_pos, get_global_mouse_position())
					
					get_viewport().set_input_as_handled()
					return
				
				# Not dragging so it's a click
				if not is_dragging:
					var click_pos = get_global_mouse_position()
					var clicked_obj = check_for_object_at(click_pos)
					
					# Mode-based click logic
					match current_mode:
						EditorMode.BUILD:
							if ui_layer.selected_scene_path != "":
								place_object(click_pos)
								
						EditorMode.EDIT:
							var is_multi = Input.is_key_pressed(KEY_CTRL)
							change_selection(clicked_obj, is_multi)
							
						EditorMode.DELETE:
							if clicked_obj != null:
								# Snapshot the single object before deleting
								var deleted_state = serialize_objects([clicked_obj])
								commit_action("delete", deleted_state, [])
								
								clicked_obj.queue_free()
				
				is_dragging = false

func _process(_delta: float) -> void:
	# Track your editor camera's Y position
	var current_camera_chunk = int(floor(camera.global_position.y / CHUNK_HEIGHT))
	
	if current_camera_chunk != last_calculated_chunk:
		update_editor_chunks(current_camera_chunk)
		last_calculated_chunk = current_camera_chunk
		
	# If we are NOT clicking the slider, make the slider follow the camera
	if scrollbar and not scrollbar.has_focus():
		# Apply the exact same flip formula in reverse to keep them synced
		var inverted_val = scrollbar.max_value + scrollbar.min_value - camera.global_position.y
		scrollbar.set_value_no_signal(inverted_val)

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
		
	# --- THE FIX: Update this path to Foreground/TransformGizmo ---
	if has_node("Foreground/TransformGizmo"):
		$Foreground/TransformGizmo.update_selection(selected_objects)

# Placement logic
func place_object(pos: Vector2) -> void:
	var object_resource = load(ui_layer.selected_scene_path)
	if object_resource:
		var new_object = object_resource.instantiate()
		
		var cell_x = floor(pos.x / GRID_SIZE)
		var cell_y = floor(pos.y / GRID_SIZE)
		var snapped_x = (cell_x * GRID_SIZE) + (GRID_SIZE / 2.0)
		var snapped_y = (cell_y * GRID_SIZE) + (GRID_SIZE / 2.0)
		
		new_object.global_position = Vector2(snapped_x, snapped_y)
		
		# Generate a unique id string
		var unique_id = str(Time.get_ticks_usec()) + str(randi() % 1000)
		new_object.set_meta("unique_id", unique_id)
		new_object.set_meta("base_rotation", 0.0)
		
		# Sets the layer of the new object
		var assigned_layer = current_layer
		if assigned_layer == 0:
			assigned_layer = 1
			
		new_object.set_meta("layer", assigned_layer)
		new_object.z_index = -assigned_layer
		
		# --- CHUNKING PLACEMENT ---
		var chunk_id = int(floor(new_object.global_position.y / CHUNK_HEIGHT))

		# Create an empty array if the chunk doesn't exist
		if not level_chunks.has(chunk_id):
			level_chunks[chunk_id] = []

		# Add to canvas for perfect chronological layering
		room_canvas.add_child(new_object)
		level_chunks[chunk_id].append(new_object)
		
		# Sleep immediately if chunk is inactive
		if chunk_id not in active_chunks:
			new_object.process_mode = Node.PROCESS_MODE_DISABLED
			new_object.visible = false
		
		var placed_state = serialize_objects([new_object])
		commit_action("place", [], placed_state)
		
		update_scrollbar_bounds()

# Deletion logic
func delete_selected_object() -> void:
	
	if not selected_objects.is_empty():
		var deleted_state = serialize_objects(selected_objects)
		commit_action("delete", deleted_state, [])
	
	# Loop through all selected objects and delete them
	for obj in selected_objects:
		if is_instance_valid(obj):
			obj.queue_free()
			
	# Passing null without Ctrl pressed automatically clears the array and hides the menu
	change_selection(null)
	
	update_scrollbar_bounds()

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
			
			var items_raw = level_data["items"]
			if typeof(items_raw) == TYPE_STRING:
				var item_strings = items_raw.split(";")
				
				for item_str in item_strings:
					if item_str.is_empty():
						continue
						
					var data = item_str.split(",")
					if data.size() < 2:
						continue
						
					# Setup our baseline default values
					var item_dict = {
						"rotation": 0.0,
						"scale_x": 1.0,
						"scale_y": 1.0,
						"layer": 1
					}
					
					# Read through array in pairs (key, value)
					for i in range(0, data.size(), 2):
						if i + 1 >= data.size():
							break
						var key = data[i]
						var val = data[i+1]
						
						match key:
							"1": item_dict["id"] = val
							"2": item_dict["scene_path"] = val
							"3": item_dict["x"] = val.to_float()
							"4": item_dict["y"] = val.to_float()
							"5": item_dict["rotation"] = val.to_float()
							"6": item_dict["scale_x"] = val.to_float()
							"7": item_dict["scale_y"] = val.to_float()
							"8": item_dict["layer"] = val.to_int()
							
					# Instantiate the object exactly like before using our parsed dict!
					var resource = load(item_dict["scene_path"])
					if resource:
						var new_object = resource.instantiate()
						new_object.global_position = Vector2(item_dict["x"], item_dict["y"])
						
						# Apply rotation
						var loaded_rot = item_dict["rotation"]
						new_object.rotation_degrees = loaded_rot
						new_object.set_meta("base_rotation", loaded_rot)
						
						# Apply scale
						new_object.scale = Vector2(item_dict["scale_x"], item_dict["scale_y"])
						
						# Apply saved ID
						new_object.set_meta("unique_id", item_dict["id"])
						
						# Apply layer data
						var loaded_layer = item_dict["layer"]
						new_object.set_meta("layer", loaded_layer)
						new_object.z_index = -loaded_layer
						
						# Expand the max_layer limit
						if loaded_layer > max_layer:
							max_layer = loaded_layer
							
						var chunk_id = int(floor(new_object.global_position.y / CHUNK_HEIGHT))

						# Create an empty array if the chunk doesn't exist
						if not level_chunks.has(chunk_id):
							level_chunks[chunk_id] = []

						# Add to canvas
						room_canvas.add_child(new_object)
						level_chunks[chunk_id].append(new_object)
						
						# Sleep immediately if chunk is inactive
						if chunk_id not in active_chunks:
							new_object.process_mode = Node.PROCESS_MODE_DISABLED
							new_object.visible = false
							
	update_scrollbar_bounds()
					
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

	# 1. Clean up the thread if the user spams the save button
	if save_thread and save_thread.is_started():
		save_thread.wait_to_finish()

	var items_string_builder: Array[String] = []
	
	# 2. Gather data on the MAIN thread (This is extremely fast)
	for object in room_canvas.get_children():
		if object is CollisionObject2D:
			var obj_parts: Array[String] = []
			
			# 1: ID
			obj_parts.append("1")
			obj_parts.append(object.get_meta("unique_id", ""))
			
			# 2: Scene Path
			obj_parts.append("2")
			obj_parts.append(object.scene_file_path)
			
			# 3 & 4: Snapped Coordinates
			obj_parts.append("3")
			obj_parts.append(str(snapped(object.global_position.x, 0.001)))
			obj_parts.append("4")
			obj_parts.append(str(snapped(object.global_position.y, 0.001)))
			
			# 5: Rotation (only if non-zero)
			if not is_zero_approx(object.rotation_degrees):
				obj_parts.append("5")
				obj_parts.append(str(snapped(object.rotation_degrees, 0.001)))
				
			# 6 & 7: Scale (only if non-one)
			if not object.scale.is_equal_approx(Vector2.ONE):
				obj_parts.append("6")
				obj_parts.append(str(snapped(object.scale.x, 0.001)))
				obj_parts.append("7")
				obj_parts.append(str(snapped(object.scale.y, 0.001)))
				
			# 8: Layer (only if non-one)
			var layer = object.get_meta("layer", 1)
			if layer != 1:
				obj_parts.append("8")
				obj_parts.append(str(layer))
				
			# Join properties with commas (e.g. "1,id,2,path,3,x,4,y")
			items_string_builder.append(",".join(obj_parts))
			
	# Join all objects with semicolons
	var compressed_items_string = ";".join(items_string_builder)
			
	var save_dict: Dictionary = {
		"level_name": current_level_name,
		"background": current_bg_path, 
		"items": compressed_items_string # Now a single optimized string!
	}
			
	# 3. Spin up the background thread!
	save_thread = Thread.new()
	save_thread.start(_write_save_data_to_disk.bind(save_dict, current_save_path))
	
func _on_save_and_quit_button_pressed() -> void:
	# Just combines save and quit logic
	_on_save_button_pressed()
	_on_quit_button_pressed()
	
func _on_quit_button_pressed() -> void:
	# Return to Level Browser scene
	get_tree().change_scene_to_file("res://scenes/rooms/level_details.tscn")
	
func _on_editor_ui_edit_action_requested(action_name: String) -> void:
	
	var start_state = serialize_objects(selected_objects)
	
	# Make sure the array isn't empty before performing edit action
	if selected_objects.is_empty():
		return
				
	# Find the center of the group 
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
				
	var end_state = serialize_objects(selected_objects)
	commit_action("edit", start_state, end_state)

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
		if child is CollisionObject2D:
			var obj_layer = child.get_meta("layer", 1)
			
			if current_layer == 0 or current_layer == obj_layer:
				child.modulate.a = 1.0  # Opaque
			else:
				child.modulate.a = 0.07 # Transparent

# COPY AND PASTE LOGIC

func copy_selection() -> void:
	# Clear the old clipboard
	clipboard.clear()
	
	# Filter out any deleted/freed objects before sorting
	var sorted_selection = []
	for obj in selected_objects:
		if is_instance_valid(obj):
			sorted_selection.append(obj)
	
	# --- FIX: Sort by visual tree index instead of creation ID ---
	sorted_selection.sort_custom(func(a, b): return a.get_index() < b.get_index())
	
	# Save the exact state of every selected object using the sorted timeline
	for obj in sorted_selection:
		if obj.scene_file_path != "":
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
			
			# Apply metadata and layer sorting
			new_object.set_meta("base_rotation", item["base_rotation"])
			new_object.set_meta("layer", item["layer"])
			new_object.z_index = -item["layer"]
			
			# Generate a brand new unique ID for the clone
			var unique_id = str(Time.get_ticks_usec()) + str(randi() % 1000)
			new_object.set_meta("unique_id", unique_id)
			
			# Put pasted objects into chunks
			var chunk_id = int(floor(new_object.global_position.y / CHUNK_HEIGHT))

			# Create an empty array if the chunk doesn't exist
			if not level_chunks.has(chunk_id):
				level_chunks[chunk_id] = []

			# Add to canvas for perfect chronological layering
			room_canvas.add_child(new_object)
			level_chunks[chunk_id].append(new_object)
			
			# Sleep immediately if chunk is inactive
			if chunk_id not in active_chunks:
				new_object.process_mode = Node.PROCESS_MODE_DISABLED
				new_object.visible = false
			
			new_selection.append(new_object)
			
			# Update the clipboard item's position so pasting again moves it another 2 blocks
			item["global_position"] = new_pos
			
	# 3. Automatically select the newly pasted objects
	for obj in new_selection:
		# Passing 'true' simulates holding Ctrl, adding them all to the group
		change_selection(obj, true)
		
	if not new_selection.is_empty():
		var pasted_state = serialize_objects(new_selection)
		commit_action("place", [], pasted_state)
		
# BOX SELECTION LOGIC
func perform_box_selection(start_p: Vector2, end_p: Vector2) -> void:
	var pos = Vector2(min(start_p.x, end_p.x), min(start_p.y, end_p.y))
	var size = Vector2(abs(start_p.x - end_p.x), abs(start_p.y - end_p.y))
	var selection_rect = Rect2(pos, size)
	
	# Loop through chunks, then loop through objects inside them
	for chunk_id in level_chunks:
		for child in level_chunks[chunk_id]:
			if is_instance_valid(child):
				if child is CollisionObject2D:
					var obj_layer = child.get_meta("layer", 1)
					
					# Make sure we only grab objects on the active layer
					if current_layer == 0 or current_layer == obj_layer:
						# Check if the object's center point is inside our rectangle
						if selection_rect.has_point(child.global_position):
							# Add it to the group safely without deselecting others
							if not selected_objects.has(child):
								selected_objects.append(child)
								if child.has_method("set_highlight"):
									child.set_highlight(true)
							
	if selection_menu:
		selection_menu.visible = selected_objects.size() > 0
		
	# --- NEW: Tell the Gizmo about the newly box-selected objects! ---
	if has_node("Foreground/TransformGizmo"):
		$Foreground/TransformGizmo.update_selection(selected_objects)

# Godot's built-in drawing engine
func _draw() -> void:
	if is_box_selecting:
		var pos = Vector2(min(mouse_down_world_pos.x, box_current_pos.x), min(mouse_down_world_pos.y, box_current_pos.y))
		var size = Vector2(abs(mouse_down_world_pos.x - box_current_pos.x), abs(mouse_down_world_pos.y - box_current_pos.y))
		var rect = Rect2(pos, size)
		
		# Draw translucent blue fill
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.3), true)
		
		# Draw solid blue outline (width of 2 pixels)
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.8), false, 2.0)

func update_editor_chunks(center_chunk: int) -> void:
	var needed_chunks = [center_chunk - 4,
						center_chunk - 3,
						center_chunk - 2,
						center_chunk - 1, 
						center_chunk, 
						center_chunk + 1,
						center_chunk + 2,
						center_chunk + 3,
						center_chunk + 4]

	# 1. Sleep chunks that went off-screen
	for chunk_id in active_chunks:
		if chunk_id not in needed_chunks:
			if level_chunks.has(chunk_id):
				for obj in level_chunks[chunk_id]:
					if is_instance_valid(obj):
						obj.process_mode = Node.PROCESS_MODE_DISABLED
						obj.visible = false

	# 2. Wake up chunks coming on-screen
	for chunk_id in needed_chunks:
		if chunk_id not in active_chunks:
			if level_chunks.has(chunk_id):
				for obj in level_chunks[chunk_id]:
					if is_instance_valid(obj):
						obj.process_mode = Node.PROCESS_MODE_INHERIT
						obj.visible = true

	active_chunks = needed_chunks
	
# UNDO/REDO ENGINE 

# 1. Takes an array of objects and converts them to pure dictionary data
func serialize_objects(objects: Array) -> Array:
	# Filter out freed objects and sort them chronologically 
	var valid_objects = []
	for obj in objects:
		if is_instance_valid(obj) and obj.scene_file_path != "":
			valid_objects.append(obj)
			
	valid_objects.sort_custom(func(a, b): return a.get_index() < b.get_index())
	
	var data_array = []
	for obj in valid_objects:
		data_array.append({
			"scene_path": obj.scene_file_path,
			"global_position": obj.global_position,
			"rotation_degrees": obj.rotation_degrees,
			"base_rotation": obj.get_meta("base_rotation", obj.rotation_degrees),
			"scale": obj.scale,
			"layer": obj.get_meta("layer", 1),
			"unique_id": obj.get_meta("unique_id", ""),
			"tree_index": obj.get_index() # Memorize its exact Z-layer order
		})
	return data_array

# 2. Pushes a new action to the history and clears the Redo timeline
func commit_action(action_type: String, old_data: Array, new_data: Array) -> void:
	undo_stack.append({
		"type": action_type,
		"old_data": old_data,
		"new_data": new_data
	})
	
	if undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()
		
	redo_stack.clear()

# 3. Undo Logic
func undo_action() -> void:
	if undo_stack.is_empty(): return
	var action = undo_stack.pop_back()
	redo_stack.append(action)
	
	match action["type"]:
		"place": remove_objects_by_id(action["new_data"])
		"delete": recreate_objects(action["old_data"])
		"edit": apply_object_state(action["old_data"])

# 4. Redo Logic
func redo_action() -> void:
	if redo_stack.is_empty(): return
	var action = redo_stack.pop_back()
	undo_stack.append(action)
	
	match action["type"]:
		"place": recreate_objects(action["new_data"])
		"delete": remove_objects_by_id(action["old_data"])
		"edit": apply_object_state(action["new_data"])

# 5. UI Button Hooks
func _on_undo_button_pressed() -> void:
	undo_action()

func _on_redo_button_pressed() -> void:
	redo_action()

# UNDO/REDO HELPER FUNCTIONS

func find_object_by_id(target_id: String) -> CollisionObject2D:
	for chunk_id in level_chunks:
		for child in level_chunks[chunk_id]:
			if is_instance_valid(child):
				if child.has_meta("unique_id") and child.get_meta("unique_id") == target_id:
					return child
	return null

func remove_objects_by_id(data_array: Array) -> void:
	for item in data_array:
		var obj = find_object_by_id(item["unique_id"])
		if obj:
			# Safety check so we don't hold a deleted object in selection
			if selected_objects.has(obj): change_selection(obj, true) 
			obj.queue_free()

func recreate_objects(data_array: Array) -> void:
	change_selection(null, false)
	var newly_created = []
	
	for item in data_array:
		var resource = load(item["scene_path"])
		if resource:
			var new_object = resource.instantiate()
			new_object.global_position = item["global_position"]
			new_object.rotation_degrees = item["rotation_degrees"]
			new_object.scale = item["scale"]
			new_object.set_meta("base_rotation", item["base_rotation"])
			new_object.set_meta("layer", item["layer"])
			new_object.z_index = -item["layer"]
			new_object.set_meta("unique_id", item["unique_id"])
			
			var chunk_id = int(floor(new_object.global_position.y / CHUNK_HEIGHT))

			# Create an empty array if the chunk doesn't exist
			if not level_chunks.has(chunk_id):
				level_chunks[chunk_id] = []

			# Add to canvas for perfect chronological layering
			room_canvas.add_child(new_object)
			
			# --- FIX: Move it back to its exact original rendering spot! ---
			if item.has("tree_index"):
				room_canvas.move_child(new_object, item["tree_index"])
			
			level_chunks[chunk_id].append(new_object)
			
			# Sleep immediately if chunk is inactive
			if chunk_id not in active_chunks:
				new_object.process_mode = Node.PROCESS_MODE_DISABLED
				new_object.visible = false

			newly_created.append(new_object)
			
	for obj in newly_created:
		change_selection(obj, true)

func apply_object_state(data_array: Array) -> void:
	for item in data_array:
		var obj = find_object_by_id(item["unique_id"])
		if obj:
			obj.global_position = item["global_position"]
			obj.rotation_degrees = item["rotation_degrees"]
			obj.scale = item["scale"]
			obj.set_meta("base_rotation", item["base_rotation"])
			obj.set_meta("layer", item["layer"])
			obj.z_index = -item["layer"]
			
# Background Worker Function for saving data
func _write_save_data_to_disk(save_dict: Dictionary, path: String) -> void:
	# --- FIX: Removed the "\t" argument to minify the JSON into a single dense line ---
	var json_string = JSON.stringify(save_dict) 
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		
	print("Background thread complete! Level safely saved to: ", path)
	
func _on_v_slider_value_changed(value: float) -> void:
	# Only move the camera if the user is actually clicking/dragging the slider
	if scrollbar.has_focus():
		# Mathematically flip the value so "up" on the slider is "up" in the world!
		var inverted_y = scrollbar.max_value + scrollbar.min_value - value
		camera.global_position.y = inverted_y

func update_scrollbar_bounds() -> void:
	if not scrollbar: return
	
	# Start with a baseline assuming the level starts near 0
	var top_y: float = 0.0
	var bottom_y: float = 0.0
	
	# Loop through all your active and sleeping chunks
	for chunk_id in level_chunks:
		for obj in level_chunks[chunk_id]:
			if is_instance_valid(obj):
				# Find the absolute highest and lowest coordinates
				top_y = min(top_y, obj.global_position.y)
				bottom_y = max(bottom_y, obj.global_position.y)
				
	# Add some "padding" so the camera doesn't slam into a hard wall at the very edge
	scrollbar.min_value = top_y - (CHUNK_HEIGHT / 2)
	scrollbar.max_value = bottom_y + (CHUNK_HEIGHT / 2)

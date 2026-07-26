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

@onready var color_picker_btn: ColorPickerButton = $EditorUI/ColorChannelMenu/ColorPickerButton
var color_before_edit: Color
var current_editing_channel: int = 0

# Undo/Redo manager
@onready var undo_manager: Node = $UndoRedoManager
# Save and load manager
@onready var save_manager: Node = $SaveLoadManager
# Copy and paste manager
@onready var clipboard_manager: Node = $ClipboardManager

# Chunking variables
const CHUNK_HEIGHT: float = 512.0
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

# Tracking for drag vs click
var mouse_down_screen_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_threshold: float = 25.0
var drawn_cells_this_stroke: Dictionary = {}
var batched_paint_objects: Array = []
# Tracks resources so we only load them from disk once
var resource_cache: Dictionary = {}

# Track for dragging object
var is_dragging_objects: bool = false
var previous_mouse_pos: Vector2 = Vector2.ZERO

# Tracking for Box Selection 
var is_box_selecting: bool = false
var mouse_down_world_pos: Vector2 = Vector2.ZERO
var box_current_pos: Vector2 = Vector2.ZERO

# Tracking for selection
var selected_objects: Array[Node2D] = []

# Tracking for Selection Cycling
var last_click_pos: Vector2 = Vector2.ZERO
var click_cycle_index: int = 0
var clicked_objects_cache: Array[Node2D] = []

# Object registry for undo redo
var object_registry: Dictionary = {}

# Current size of one grid
const GRID_SIZE: float = 64.0

# Zoom settings
var min_zoom: float = 0.20  # How far out you can see
var max_zoom: float = 3.0  # How close you can zoom in
var zoom_step: float = 0.2 # How much the buttons zoom per click

# Playtesting variables
var is_playtesting: bool = false
var test_player: BasePlayer = null
var pre_test_camera_pos: Vector2 = Vector2.ZERO
var playtest_trail: Line2D = null # NEW: Tracks the path

# IMPORTANT: Make sure to paste the exact path to your player scene here!
const PLAYER_SCENE = preload("res://scenes/Player/player.tscn")

# Game state
var paused: bool = false:
	set(value):
		paused = value
		if camera:
			camera.set_process_unhandled_input(!paused)
			camera.set_process_input(!paused)

@export var hitboxes_on := false

func _ready() -> void:
	# Hide the entire contextual menu at the start
	if selection_menu:
		selection_menu.visible = false
	if pause_menu:
		pause_menu.visible = false
	
	# Manually connect the buttons and bind their specific channel ID
	$EditorUI/ColorChannelMenu/Channel0Button.pressed.connect(_on_color_channel_selected.bind(0))
	$EditorUI/ColorChannelMenu/Channel1Button.pressed.connect(_on_color_channel_selected.bind(1))
	$EditorUI/ColorChannelMenu/Channel2Button.pressed.connect(_on_color_channel_selected.bind(2))
	$EditorUI/ColorChannelMenu/Channel3Button.pressed.connect(_on_color_channel_selected.bind(3))
	$EditorUI/ColorChannelMenu/Channel4Button.pressed.connect(_on_color_channel_selected.bind(4))
	$EditorUI/ColorChannelMenu/Channel5Button.pressed.connect(_on_color_channel_selected.bind(5))
	$EditorUI/ColorChannelMenu/Channel6Button.pressed.connect(_on_color_channel_selected.bind(6))
	$EditorUI/ColorChannelMenu/Channel7Button.pressed.connect(_on_color_channel_selected.bind(7))
	$EditorUI/ColorChannelMenu/Channel8Button.pressed.connect(_on_color_channel_selected.bind(8))
	$EditorUI/ColorChannelMenu/Channel9Button.pressed.connect(_on_color_channel_selected.bind(9))
	$EditorUI/ColorChannelMenu/Channel10Button.pressed.connect(_on_color_channel_selected.bind(10))
	
	color_picker_btn.pressed.connect(_on_color_picker_pressed)
	color_picker_btn.popup_closed.connect(_on_color_picker_closed)
	
	color_picker_btn.color_changed.connect(_on_picker_color_changed)
	
	# Turn the editor mouse features back on from when they were turned off during play_scene
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# If the global script has a level queued up, load it immediately
	if Global.level_to_load != "":
		save_manager.current_save_path = Global.level_to_load # Makes sure to save to this file later
		save_manager.load_level(save_manager.current_save_path)
		
	# Connect to the Gizmo's broadcasts
	if has_node("Foreground/TransformGizmo"):
		var gizmo = $Foreground/TransformGizmo
		gizmo.transform_started.connect(_on_gizmo_transform_started)
		gizmo.transform_ended.connect(_on_gizmo_transform_ended)
		
func _exit_tree() -> void:
	# Intercepts the scene closure and forces the engine 
	# to wait for the background thread to finish saving.
	if save_manager.save_thread and save_manager.save_thread.is_started():
		save_manager.save_thread.wait_to_finish()
		
func _input(event: InputEvent) -> void:
	if paused: return
	
	# 1. Protect Mouse Motion from UI theft during active drags
	if event is InputEventMouseMotion:
		if is_dragging_objects or is_box_selecting or is_dragging:
			_handle_mouse_motion(event)
			
			# FIX: Only feed the event to the camera if we are purely panning
			if is_dragging and not is_dragging_objects and not is_box_selecting:
				if camera.has_method("_unhandled_input"):
					camera._unhandled_input(event)
				elif camera.has_method("_input"):
					camera._input(event)
					
			get_viewport().set_input_as_handled()
			
	# 2. Protect Mouse Release from UI theft so things don't get "stuck"
	elif event is InputEventMouseButton and not event.pressed:
		if is_dragging_objects or is_box_selecting or is_dragging:
			_handle_mouse_button(event)
			
			# FIX: Only feed the release to the camera if we were purely panning
			if is_dragging and not is_dragging_objects and not is_box_selecting:
				if camera.has_method("_unhandled_input"):
					camera._unhandled_input(event)
				elif camera.has_method("_input"):
					camera._input(event)
					
			get_viewport().set_input_as_handled()
			
func _unhandled_input(event: InputEvent) -> void:
	if paused: return
	
	# Scrollbar fix: Force scrollbar to let go on click
	if event is InputEventMouseButton and event.is_pressed():
		if scrollbar and scrollbar.has_focus():
			scrollbar.release_focus()

	# 1. Route Key Presses
	if event is InputEventKey and event.pressed:
		if _handle_hotkeys(event):
			return # Stop processing if a hotkey was triggered

	# 2. Route Mouse Movement
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

	# 3. Route Mouse Clicks and Scrolls
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)

func _process(_delta: float) -> void:
	# 1. Determine what the chunk system should follow
	var tracker_y = camera.global_position.y
	if is_playtesting and is_instance_valid(test_player):
		tracker_y = test_player.global_position.y
		
		# PLAYER TRAIL LOGIC
		if is_instance_valid(playtest_trail):
			var current_pos = test_player.global_position
			
			# Only add a new point if the line is empty OR the player has moved at least 10 pixels
			if playtest_trail.get_point_count() == 0 or playtest_trail.get_point_position(playtest_trail.get_point_count() - 1).distance_to(current_pos) > 10.0:
				playtest_trail.add_point(current_pos)
		
	var current_camera_chunk = int(floor(tracker_y / CHUNK_HEIGHT))
	
	# 2. Updates chunk if in new one
	if current_camera_chunk != last_calculated_chunk:
		update_editor_chunks(current_camera_chunk)
		last_calculated_chunk = current_camera_chunk
		
	# 3. If user is NOT clicking the slider AND not testing, make the slider follow the camera
	if scrollbar and not scrollbar.has_focus() and not is_playtesting:
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
	
	# Force chunks to recalculate their radius based on the new zoom 
	var current_camera_chunk = int(floor(camera.global_position.y / CHUNK_HEIGHT))
	update_editor_chunks(current_camera_chunk)

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
	
# Changed signature to accept the is_press flag
func check_for_object_at(pos: Vector2, is_press: bool = false) -> Node2D:
	# Only update the math and advance the cycle when the mouse button goes DOWN
	if is_press:
		# Scales the click tolerance with the camera zoom 
		var zoom_adjusted_tolerance = 20.0 / camera.zoom.x
		
		# If clicking in the same general spot, cycle to the next object in the array
		if pos.distance_to(last_click_pos) < zoom_adjusted_tolerance and clicked_objects_cache.size() > 0:
			click_cycle_index = (click_cycle_index + 1) % clicked_objects_cache.size()
		else:
			# Different spot, clear the cache and find everything under the mouse
			clicked_objects_cache.clear()
			click_cycle_index = 0
			last_click_pos = pos
			
			for chunk_id in active_chunks:
				if level_chunks.has(chunk_id):
					for obj in level_chunks[chunk_id]:
						if is_instance_valid(obj) and obj.visible:
							var is_clicked = false
							
							# Precise Sprite Check
							for child in obj.get_children():
								if child is Sprite2D and child.texture:
									var sprite_local_pos = child.to_local(pos)
									if child.get_rect().has_point(sprite_local_pos):
										is_clicked = true
									break 
									
							# Fallback Box Check 
							if not is_clicked:
								var local_pos = obj.to_local(pos)
								var half_size = GRID_SIZE / 2.0
								var local_rect = Rect2(Vector2(-half_size, -half_size), Vector2(GRID_SIZE, GRID_SIZE))
								if local_rect.has_point(local_pos):
									is_clicked = true
							
							# If clicked, check the layer and add to the cache!
							if is_clicked:
								var obj_layer = obj.get_meta("layer", 1)
								if current_layer == 0 or current_layer == obj_layer:
									clicked_objects_cache.append(obj)
									
			# Sort the cached array so the visually highest objects are first
			clicked_objects_cache.sort_custom(func(a, b):
				if a.z_index != b.z_index:
					return a.z_index > b.z_index # Sort by Z-Index first
				return a.get_index() > b.get_index() # Tie breaker: Tree Index
			)

	# Return the currently active object in the cycle (applies to both Mouse Down and Mouse Up)
	if clicked_objects_cache.size() > 0:
		var obj = clicked_objects_cache[click_cycle_index]
		# Safety check just in case the object was deleted via Backspace while selected
		if is_instance_valid(obj):
			return obj

	return null

# Change selected object
func change_selection(clicked_obj: Node2D, is_multi: bool = false) -> void:
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
	
	if ui_layer:
		ui_layer.update_selected_target(selected_objects)
		
	# Update the transform gizmo
	if has_node("Foreground/TransformGizmo"):
		$Foreground/TransformGizmo.update_selection(selected_objects)

# Placement logic
func place_object(pos: Vector2, is_painting: bool = false) -> void:
	var path = ui_layer.selected_scene_path
	
	# If we haven't loaded this object yet, load it from disk and save it to memory
	if not resource_cache.has(path):
		resource_cache[path] = load(path)
		
	# Grab the pre-loaded resource from fast memory instead of the slow hard drive
	var object_resource = resource_cache[path]
	
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
		
		# Register the new object instantly
		object_registry[unique_id] = new_object
		
		# Sets the layer of the new object
		var assigned_layer = current_layer
		if assigned_layer == 0:
			assigned_layer = 1
			
		new_object.set_meta("layer", assigned_layer)
		new_object.z_index = -assigned_layer
		
		new_object.set_meta("color_channel", 0)
		var target_color = Global.get_channel_color(0)
		
		if new_object is Sprite2D:
			new_object.modulate = target_color
		else:
			var sprite = new_object.get_node_or_null("Sprite2D")
			if sprite:
				sprite.modulate = target_color
				new_object.modulate = Color(1, 1, 1, 1.0) # Explicitly keep root opaque
			else:
				new_object.modulate = target_color
		
		# CHUNKING PLACEMENT
		var chunk_id = int(floor(new_object.global_position.y / CHUNK_HEIGHT))

		if not level_chunks.has(chunk_id):
			level_chunks[chunk_id] = []

		room_canvas.add_child(new_object)
		level_chunks[chunk_id].append(new_object)
		
		if chunk_id not in active_chunks:
			new_object.process_mode = Node.PROCESS_MODE_DISABLED
			new_object.visible = false
			
		# O(1) SCROLLBAR EXPANSION 
		var pad = CHUNK_HEIGHT / 2.0
		if scrollbar.min_value == 0 and scrollbar.max_value == 0:
			update_scrollbar_bounds()
		else:
			if new_object.global_position.y - pad < scrollbar.min_value:
				scrollbar.min_value = new_object.global_position.y - pad
			if new_object.global_position.y + pad > scrollbar.max_value:
				scrollbar.max_value = new_object.global_position.y + pad

		# Batching logic
		if not is_painting:
			# Normal single click: commit to undo stack and select it immediately
			var placed_state = undo_manager.serialize_objects([new_object])
			undo_manager.commit_action("place", [], placed_state)
			change_selection(new_object)
		else:
			# Continuous stroke: queue it up for the undo batch and SKIP selection
			batched_paint_objects.append(new_object)
		
# Deletion logic
func delete_selected_object() -> void:
	# Snaps action in undo manager
	if not selected_objects.is_empty():
		var deleted_state = undo_manager.serialize_objects(selected_objects)
		undo_manager.commit_action("delete", deleted_state, [])
	
	# Loop through all selected objects and delete them
	for obj in selected_objects:
		if is_instance_valid(obj):
			# Remove from registry before freeing
			var uid = obj.get_meta("unique_id", "")
			if uid != "":
				object_registry.erase(uid)
				
			obj.queue_free()
			
	# Passing null without Ctrl pressed automatically clears the array and hides the menu
	change_selection(null)

func _on_delete_button_pressed() -> void:
	delete_selected_object()

					
# Called when the user picks a new background
func change_background(new_path: String) -> void:
	var new_texture = load(new_path)
	if new_texture:
		bg_rect.texture = new_texture
		save_manager.current_bg_path = new_path # Update the variable so it saves correctly later

# Tab switching logic
func _on_main_tab_container_tab_changed(tab: int) -> void:
	# 0 = Build, 1 = Edit, 2 = Delete
	current_mode = tab as EditorMode

	# Only turn on Godot's physics picking in Edit mode so the Gizmo Area2Ds work
	if current_mode == EditorMode.EDIT:
		get_viewport().physics_object_picking = true
	else:
		get_viewport().physics_object_picking = false

# Pause Menu logic
func _on_pause_button_pressed() -> void:
	# Shows name of level
	if level_name_label:
		level_name_label.text = save_manager.current_level_name
		
	# Reveal the menu
	if pause_menu:
		pause_menu.visible = true
	paused = true

func _on_resume_button_pressed() -> void:
	# Hide the menu to go back to editing
	if pause_menu:
		pause_menu.visible = false
	paused = false
	
func _on_editor_ui_edit_action_requested(action_name: String) -> void:
	# 1. Catch the UI toggle before doing any object logic
	if action_name == "show_hide_gizmo":
		if has_node("Foreground/TransformGizmo"):
			$Foreground/TransformGizmo.toggle_visibility()
		return # Exit early so we don't trigger undo/redo saves or loop through objects
	
	# Make sure the array isn't empty before performing edit action
	if selected_objects.is_empty():
		return
		
	var start_state = undo_manager.serialize_objects(selected_objects)
				
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
				var new_rot = obj.get_meta("base_rotation", obj.rotation_degrees) - 30
				obj.set_meta("base_rotation", new_rot)
				obj.rotation_degrees = new_rot
				
				# 2. Orbit the position around the group center
				var offset = obj.global_position - group_center
				
				# Godot's rotated() function requires radians, so convert -90 degrees
				var rotated_offset = offset.rotated(deg_to_rad(-30))
				
				# Apply the new offset to the center point
				obj.global_position = group_center + rotated_offset
			
			"rotate_right":
				# 1. Rotate the object itself 
				var new_rot = obj.get_meta("base_rotation", obj.rotation_degrees) + 30
				obj.set_meta("base_rotation", new_rot)
				obj.rotation_degrees = new_rot
				
				# 2. Orbit the position around the group center
				var offset = obj.global_position - group_center
				
				# Godot's rotated() function requires radians, so convert 90 degrees
				var rotated_offset = offset.rotated(deg_to_rad(30))
				
				# Apply the new offset to the center point
				obj.global_position = group_center + rotated_offset
				
	var end_state = undo_manager.serialize_objects(selected_objects)
	undo_manager.commit_action("edit", start_state, end_state)

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
		
	# Refresh the screen transparency when the layer changes
	refresh_layer_visibility()
	
func refresh_layer_visibility() -> void:
	# Only sweep the on-screen chunks for better time complexity
	for chunk_id in active_chunks:
		if level_chunks.has(chunk_id):
			for child in level_chunks[chunk_id]:
				if is_instance_valid(child) and child is Node2D:
					var obj_layer = child.get_meta("layer", 1)
					
					if current_layer == 0 or current_layer == obj_layer:
						child.modulate.a = 1.0 # Force parent fully opaque when active
					else:
						child.modulate.a = 0.08 # Faded out for inactive layers
		
# BOX SELECTION LOGIC
func perform_box_selection(start_p: Vector2, end_p: Vector2) -> void:
	var pos = Vector2(min(start_p.x, end_p.x), min(start_p.y, end_p.y))
	var size = Vector2(abs(start_p.x - end_p.x), abs(start_p.y - end_p.y))
	var selection_rect = Rect2(pos, size)
	
	# Flag to track if we actually grabbed anything
	var selection_changed: bool = false 
	
	# Create a temporary dictionary for O(1) lookups 
	var fast_selection_check = {}
	for obj in selected_objects:
		fast_selection_check[obj] = true
	
	# Loop through ACTIVE chunks only, not the whole level 
	for chunk_id in active_chunks:
		if level_chunks.has(chunk_id):
			for child in level_chunks[chunk_id]:
				if is_instance_valid(child):
					if child is Node2D:
						var obj_layer = child.get_meta("layer", 1)
						
						# Make sure we only grab objects on the active layer
						if current_layer == 0 or current_layer == obj_layer:
							# Check if the object's center point is inside our rectangle
							if selection_rect.has_point(child.global_position):
								
								# Fixes bad time complexity: Check the dictionary instead of the array 
								if not fast_selection_check.has(child):
									selected_objects.append(child)
									fast_selection_check[child] = true # Add it so we don't grab duplicates later
									
									if child.has_method("set_highlight"):
										child.set_highlight(true)
									
									selection_changed = true 
							
	# Only force UI and Gizmo updates if we caught something new
	if selection_changed:
		if selection_menu:
			selection_menu.visible = selected_objects.size() > 0
			
		# Tell the Gizmo about the newly box-selected objects
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
		
		# Draw solid blue outline with width of 2 pixels
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.8), false, 2.0)

func update_editor_chunks(center_chunk: int) -> void:
	# Calculate the total vertical space currently visible to the camera
	var visible_height: float = get_viewport_rect().size.y / camera.zoom.y

	# Halve it (for a radius), divide by your chunk height, and add 2 as a safety buffer
	var render_radius: int = int(ceil((visible_height / 2.0) / CHUNK_HEIGHT)) + 2
	
	var needed_chunks: Array[int] = []
	for i in range(-render_radius, render_radius + 1):
		needed_chunks.append(center_chunk + i)

	# Fix: Create a temporary dictionary for O(1) lookups
	var fast_selection_check = {}
	for sel in selected_objects:
		fast_selection_check[sel] = true

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
						
						# Refresh visuals on wake 
						var channel = obj.get_meta("color_channel", 0)
						var obj_layer = obj.get_meta("layer", 1)
						var target_color = Global.get_channel_color(channel)
						
						if obj is Sprite2D:
							# CASE 1: Object IS the sprite (Decorations)
							if current_layer != 0 and current_layer != obj_layer:
								target_color.a = 0.05
							obj.modulate = target_color
						else: # CASE 2: Object has sprite as a child
							var sprite = obj.get_node_or_null("Sprite2D")
							if sprite:
								# Apply full color AND alpha directly to the sprite
								sprite.modulate = target_color 
				
							# Not on the layer, so fade every node in the object including hitbox
							if current_layer != 0 and current_layer != obj_layer:
								obj.modulate = Color(1, 1, 1, 0.05) # Faded out
							else: # The object is on the current layer, so keep main object completely opaque so hitbox show
								obj.modulate = Color(1, 1, 1, 1.0) # Keep root opaque so hitboxes show
						
						# Fix o(n): Check the Dictionary instead of the Array 
						if fast_selection_check.has(obj) and obj.has_method("set_highlight"):
							obj.set_highlight(true)
						
						var hitbox = obj.get_node_or_null("HitboxSprite")
						if hitbox:
							hitbox.visible = hitboxes_on
							
	active_chunks = needed_chunks

# Undo/Redo Buttons
func _on_undo_button_pressed() -> void:
	undo_manager.undo_action()

func _on_redo_button_pressed() -> void:
	undo_manager.redo_action()
	
func _on_v_slider_value_changed(value: float) -> void:
	# Only move the camera if the user is actually clicking/dragging the slider
	if scrollbar.has_focus():
		# Mathematically flip the value so "up" on the slider is "up" in the world
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
	
# GIZMO UNDO/REDO HANDLERS
func _on_gizmo_transform_started() -> void:
	# Overwrite the global drag_start_state with the object's current scale/rotation
	undo_manager.drag_start_state = undo_manager.serialize_objects(selected_objects)

func _on_gizmo_transform_ended() -> void:
	# Capture the final state and commit the action to the stack
	var drag_end_state = undo_manager.serialize_objects(selected_objects)
	undo_manager.commit_action("edit", undo_manager.drag_start_state, drag_end_state)

func _on_color_channel_selected(channel_id: int) -> void:
	# Snap the start state for undo/redo manager
	var start_state = undo_manager.serialize_objects(selected_objects)

	for obj in selected_objects:
		if is_instance_valid(obj):
			obj.set_meta("color_channel", channel_id)
			obj.set_highlight(true)

	var end_state = undo_manager.serialize_objects(selected_objects)
	undo_manager.commit_action("edit", start_state, end_state)

	# 1. Tell the editor which channel we are currently editing
	current_editing_channel = channel_id
	
	# 2. Force the color box to physically change to the correct color
	color_picker_btn.color = Global.get_channel_color(channel_id)

func apply_level_colors(json_color_data: Dictionary) -> void:
	# 1. Wipe the colors from the previous level
	Global.reset_colors()
	
	# 2. Loop through the new JSON data
	for channel_id_str in json_color_data.keys():
		
		# JSON keys are always strings, so convert the ID back to an integer
		var channel_id = int(channel_id_str) 
		
		# Grab the hex string associated with that ID
		var color_hex = json_color_data[channel_id_str]
		
		# 3. Convert the hex string to a Godot Color and store it in Global
		Global.active_level_colors[channel_id] = Color(color_hex)

func _on_picker_color_changed(new_color: Color) -> void:
	Global.active_level_colors[current_editing_channel] = new_color
	
	# Create a temporary dictionary for O(1) lookups
	var fast_selection_check = {}
	for obj in selected_objects:
		fast_selection_check[obj] = true
	
	# Sweep through ACTIVE chunks only
	for chunk_id in active_chunks:
		if level_chunks.has(chunk_id):
			for obj in level_chunks[chunk_id]:
				if is_instance_valid(obj):
					# If the object is on this channel, update its tint
					if obj.get_meta("color_channel", 0) == current_editing_channel:
						
						# Use dictionary for better time complexity
						if fast_selection_check.has(obj):
							# If it IS selected, trigger its highlight function to refresh the base color 
							if obj.has_method("set_highlight"):
								obj.set_highlight(true)
						else:
							# If it is NOT selected, apply the raw color directly
							if obj is Sprite2D:
								obj.modulate = new_color
							else:
								var sprite = obj.get_node_or_null("Sprite2D")
								if sprite:
									sprite.modulate = new_color

func _on_color_picker_pressed() -> void:
	# Snapshot the color right before the user starts messing with the wheel
	color_before_edit = color_picker_btn.color

func _on_color_picker_closed() -> void:
	var final_color = color_picker_btn.color
	
	# Only commit to the undo stack if they actually changed the color
	if final_color != color_before_edit:
		var old_state = [{"channel": current_editing_channel, "color": color_before_edit}]
		var new_state = [{"channel": current_editing_channel, "color": final_color}]
		undo_manager.commit_action("color_change", old_state, new_state)

func _handle_hotkeys(event: InputEventKey) -> bool:
	# Backspace for deletion
	if event.keycode == KEY_BACKSPACE:
		delete_selected_object()
		return true 

	# Copy (Ctrl + C)
	if event.keycode == KEY_C and Input.is_key_pressed(KEY_CTRL):
		clipboard_manager.copy_selection()
		return true
		
	# Paste (Ctrl + V) 
	if event.keycode == KEY_V and Input.is_key_pressed(KEY_CTRL):
		clipboard_manager.paste_clipboard()
		return true
		
	# Undo (Ctrl + Z)
	if event.keycode == KEY_Z and Input.is_key_pressed(KEY_CTRL):
		undo_manager.undo_action()
		return true
		
	# Redo (Ctrl + Y)
	if event.keycode == KEY_Y and Input.is_key_pressed(KEY_CTRL):
		undo_manager.redo_action()
		return true

	return false # No hotkeys matched
	
# Handles click and drag
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# Only care if the left mouse button is held down
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
		
	# CONTINUOUS BRUSH (BUILD MODE CTRL PRESS)
	if current_mode == EditorMode.BUILD and Input.is_key_pressed(KEY_CTRL):
		if ui_layer.selected_scene_path != "":
			var current_pos = get_global_mouse_position()
			
			var cell_x = floor(current_pos.x / GRID_SIZE)
			var cell_y = floor(current_pos.y / GRID_SIZE)
			var current_cell = Vector2(cell_x, cell_y)
			
			if not drawn_cells_this_stroke.has(current_cell):
				# Pass 'true' to signal that we are dragging
				place_object(current_pos, true) 
				drawn_cells_this_stroke[current_cell] = true
				
		get_viewport().set_input_as_handled()
		return
		
	# BOX SELECTION (EDIT MODE CTRL PRESS)
	if current_mode == EditorMode.EDIT and Input.is_key_pressed(KEY_CTRL):
		if event.position.distance_to(mouse_down_screen_pos) > drag_threshold:
			is_box_selecting = true
			box_current_pos = get_global_mouse_position()
			
			camera.set_process_unhandled_input(false)
			camera.set_process_input(false)
			camera.set_process(false)
			
			queue_redraw() 
			get_viewport().set_input_as_handled()
			return
			
	# CONTINUOUS ERASER (DELETE MODE CTRL PRESS)
	if current_mode == EditorMode.DELETE and Input.is_key_pressed(KEY_CTRL):
		var current_pos = get_global_mouse_position()
		
		var obj_to_delete = check_for_object_at(current_pos, true) 
		
		if obj_to_delete != null:
			var deleted_state = undo_manager.serialize_objects([obj_to_delete])
			undo_manager.commit_action("delete", deleted_state, [])
			
			# Remove from registry before freeing
			var uid = obj_to_delete.get_meta("unique_id", "")
			if uid != "":
				object_registry.erase(uid)
			
			obj_to_delete.queue_free()
			
		get_viewport().set_input_as_handled()
		return 
		
	if event.position.distance_to(mouse_down_screen_pos) > drag_threshold:
		is_dragging = true
		
	if is_dragging_objects:
		var current_mouse_pos = get_global_mouse_position()
		var mouse_delta = current_mouse_pos - previous_mouse_pos
		
		# Just loop through the selection directly
		for obj in selected_objects:
			if is_instance_valid(obj):
				obj.global_position += mouse_delta
				
		previous_mouse_pos = current_mouse_pos
		get_viewport().set_input_as_handled()
		
		# Moves transform gizmo with dragged objects
		if has_node("Foreground/TransformGizmo"):
			$Foreground/TransformGizmo.global_position += mouse_delta
	
# Handles just clicks
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Zoom by scrolling the mouse wheel up or down
	if event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			apply_zoom_at_mouse(camera.zoom.x + zoom_step/5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			apply_zoom_at_mouse(camera.zoom.x - zoom_step/5)

	# Left click logic
	if event.button_index == MOUSE_BUTTON_LEFT:
		# MOUSE BUTTON PRESSED DOWN
		if event.pressed:
			# 1. Record the exact starting positions for future distance/drag calculations
			mouse_down_screen_pos = event.position
			mouse_down_world_pos = get_global_mouse_position() 
			
			# 2. Reset tracking variables for a fresh click
			is_dragging = false
			drawn_cells_this_stroke.clear()
			
			# 3. If holding Ctrl, instantly freeze the camera so user can safely use tools like box-select
			if Input.is_key_pressed(KEY_CTRL):
				camera.set_process_unhandled_input(false)
				camera.set_process_input(false)
				camera.set_process(false)
				get_viewport().set_input_as_handled()
		
			# 4. Check if we are trying to grab an object to move it (Edit or Delete mode)
			if current_mode == EditorMode.EDIT or current_mode == EditorMode.DELETE:
				var click_pos = get_global_mouse_position()
				
				# Advance the selection cycle and calculate what is under the mouse
				var _clicked_obj = check_for_object_at(click_pos, true) 
				
				# Check if the mouse is touching ANY object in the currently active selection group
				var is_touching_selection = clicked_objects_cache.any(func(obj): return is_instance_valid(obj) and selected_objects.has(obj))

				# Check if the mouse is touching the transform gizmo handles
				var is_touching_gizmo = false
				if current_mode == EditorMode.EDIT and has_node("Foreground/TransformGizmo"):
					var gizmo = $Foreground/TransformGizmo
					if gizmo.visible:
						var handles = [gizmo.scale_handle, gizmo.rotate_handle, gizmo.scale_x_handle, gizmo.scale_y_handle, gizmo.skew_handle, gizmo.skew_y_handle]
						
						for handle in handles:
							if is_instance_valid(handle) and click_pos.distance_to(handle.global_position) < 24.0:
								is_touching_gizmo = true
								break

				# If we clicked our selection, are NOT holding Ctrl, and are NOT using the Gizmo, start dragging!
				if current_mode == EditorMode.EDIT and is_touching_selection and not Input.is_key_pressed(KEY_CTRL) and not is_touching_gizmo:
					is_dragging_objects = true
					previous_mouse_pos = click_pos
					
					# Save the objects' original positions for the Undo system
					undo_manager.drag_start_state = undo_manager.serialize_objects(selected_objects)
					
					# Freeze the camera so we don't accidentally pan while moving the objects
					camera.set_process_unhandled_input(false)
					camera.set_process_input(false)
					camera.set_process(false)
					
					get_viewport().set_input_as_handled()
					return
			
			# MOUSE BUTTON RELEASED
		elif not event.pressed:
			# 1. Unfreeze the camera so normal panning works again
			camera.set_process_unhandled_input(true)
			camera.set_process_input(true)
			camera.set_process(true)
			
			# Batch commit logic
			if batched_paint_objects.size() > 0:
				var placed_state = undo_manager.serialize_objects(batched_paint_objects)
				undo_manager.commit_action("place", [], placed_state)
				batched_paint_objects.clear()
			
			# 2. Finish Object Dragging
			if is_dragging_objects:
				is_dragging_objects = false
				
				# If we actually dragged them (crossed the threshold), commit the final positions to the Undo stack
				if is_dragging:
					var drag_end_state = undo_manager.serialize_objects(selected_objects)
					undo_manager.commit_action("edit", undo_manager.drag_start_state, drag_end_state)
					
					# Force the Gizmo to recalculate its exact center point after being moved
					if has_node("Foreground/TransformGizmo"):
						$Foreground/TransformGizmo.update_selection(selected_objects)
						
					get_viewport().set_input_as_handled()
					return
			
			# 3. Finish Box Selection
			if is_box_selecting:
				is_box_selecting = false
				queue_redraw() # Clears the blue visual box 
				perform_box_selection(mouse_down_world_pos, get_global_mouse_position())
				get_viewport().set_input_as_handled()
				return
			
			# 4. Handle Standard Single Clicks (Only triggers if the mouse stayed relatively still)
			if not is_dragging:
				var click_pos = get_global_mouse_position()
				
				# Grab the object under the mouse (pass false because we only update cycle math on press)
				var clicked_obj = check_for_object_at(click_pos, false) 
				
				match current_mode:
					EditorMode.BUILD:
						if ui_layer.selected_scene_path != "":
							# Only place an object if the continuous brush wasn't just used
							if drawn_cells_this_stroke.is_empty():
								place_object(click_pos)
							
					EditorMode.EDIT:
						# If holding Ctrl, enable multi-select toggling
						var is_multi = Input.is_key_pressed(KEY_CTRL)
						change_selection(clicked_obj, is_multi)
						
					EditorMode.DELETE:
						if clicked_obj != null:
							# Commit to undo stack then destroy
							var deleted_state = undo_manager.serialize_objects([clicked_obj])
							undo_manager.commit_action("delete", deleted_state, [])
							
							# Remove from registry before freeing
							var uid = clicked_obj.get_meta("unique_id", "")
							if uid != "":
								object_registry.erase(uid)
							
							clicked_obj.queue_free()
			
			# Reset the general drag flag so the next click starts fresh
			is_dragging = false
			
func update_ground_color(tab_index: int, new_color: Color) -> void:
	# Match the tab index to the correct ground layer
	if tab_index == 0:
		bg_rect.modulate = new_color
	elif tab_index == 1:
		pass # Add your middleground rect modulate here later
	elif tab_index == 2:
		pass # Add your foreground rect modulate here later
		
	# Store the color as a hex string so the save manager can write it to JSON
	save_manager.ground_colors[tab_index] = new_color.to_html()

# PLAYTESTING LOGIC
func toggle_playtest() -> void:
	if not is_playtesting:
		start_playtest()
	else:
		stop_playtest()

func start_playtest() -> void:
	is_playtesting = true
	
	# PLAYER TRAIL LOGIC
	if not is_instance_valid(playtest_trail):
		playtest_trail = Line2D.new()
		playtest_trail.width = 4.0
		# Give it a bright orange color so it stands out, with slight transparency
		playtest_trail.default_color = Color(1.0, 0.5, 0.0, 0.8) 
		playtest_trail.z_index = 100 # Force it to draw on top of the grid and objects
		room_canvas.add_child(playtest_trail)
	else:
		# Wipe the previous playtest's line clean
		playtest_trail.clear_points()

	# 1. Save where the editor camera was looking
	pre_test_camera_pos = camera.global_position
	
	# 2. Spawn the player
	test_player = PLAYER_SCENE.instantiate()
	
	# Spawn the player exactly at 0,0
	test_player.global_position = Vector2(0, 0)
	
	# Match the editor's hitbox visibility setting
	if test_player.has_method("toggle_hitbox"):
		test_player.toggle_hitbox(hitboxes_on)
		
	# 3. Add to the canvas so it renders chronologically with the level
	room_canvas.add_child(test_player)
	
	# Tell the engine to switch to the player's camera
	var player_cam = test_player.get_node_or_null("Camera2D")
	if player_cam:
		player_cam.make_current()
	
	# 4. Connect the death signal to automatically end the playtest if they die
	test_player.player_died.connect(stop_playtest)
	
	# 5. Freeze all editor inputs (stops placing blocks and panning)
	paused = true
	
	# 6. Hide the editor UI
	ui_layer.toggle_playtest_ui(true)

func stop_playtest() -> void:
	is_playtesting = false
	
	# 1. Destroy the test player
	if is_instance_valid(test_player):
		test_player.queue_free()
		test_player = null
		
	# 2. Force the editor camera to take visual control back
	if camera:
		camera.make_current()
		camera.global_position = pre_test_camera_pos
		
	# 3. Unfreeze the editor tools
	paused = false
	
	# 4. Restore the editor UI
	ui_layer.toggle_playtest_ui(false)
	
	# 5. Snap the chunks back to the editor camera instantly
	var current_camera_chunk = int(floor(camera.global_position.y / CHUNK_HEIGHT))
	update_editor_chunks(current_camera_chunk)
	

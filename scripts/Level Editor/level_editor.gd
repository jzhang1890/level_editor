extends Node2D

enum EditorMode { EDIT, DELETE, PLACE }
var current_mode: EditorMode = EditorMode.EDIT

@export var item_catalog: Array[PackedScene] = []
@export var grid_size: int = 64

@onready var placed_objects_node = $MainCanvas/PlacedObjects
@onready var preview_sprite = $PreviewSprite
@onready var grid_container = $UI/ItemSelectionPanel/GridContainer
@onready var camera = $Camera2D

@onready var edit_button = $UI/ActionPanel/EditButton
@onready var delete_button = $UI/ActionPanel/DeleteButton

var current_selected_index: int = -1
var is_ui_hovered: bool = false

# Edit Mode specific variables
var is_panning: bool = false
var dragging_object: Node2D = null

func _ready():
	setup_ui_catalog()
	
	# Configure buttons to behave like toggle switches
	edit_button.toggle_mode = true
	delete_button.toggle_mode = true
	
	# Connect mode buttons
	edit_button.toggled.connect(_on_edit_toggled)
	delete_button.toggled.connect(_on_delete_toggled)
	
	# Default to Edit Mode on startup
	switch_mode(EditorMode.EDIT)

func _process(_delta):
	# Only show and track the placement preview if we are actually in PLACE mode
	if current_mode == EditorMode.PLACE and current_selected_index != -1:
		var mouse_pos = get_global_mouse_position()
		var snapped_pos = (mouse_pos / grid_size).floor() * grid_size
		preview_sprite.global_position = snapped_pos

# --- Mode Controller (Handles Automatic Toggling) ---
func switch_mode(new_mode: EditorMode):
	current_mode = new_mode
	
	# Temporarily block signals so setting 'button_pressed' programmatically 
	# doesn't trigger infinite loop feedback
	edit_button.set_block_signals(true)
	delete_button.set_block_signals(true)
	
	# Reset states
	preview_sprite.visible = false
	is_panning = false
	dragging_object = null
	
	match current_mode:
		EditorMode.EDIT:
			edit_button.button_pressed = true
			delete_button.button_pressed = false
			current_selected_index = -1
		EditorMode.DELETE:
			edit_button.button_pressed = false
			delete_button.button_pressed = true
			current_selected_index = -1
		EditorMode.PLACE:
			edit_button.button_pressed = false
			delete_button.button_pressed = false
			
	edit_button.set_block_signals(false)
	delete_button.set_block_signals(false)

# --- UI Signal Receivers ---
func _on_edit_toggled(is_pressed: bool):
	if is_pressed:
		switch_mode(EditorMode.EDIT)
	else:
		# Prevent untoggling into "no mode". Must always be in a mode.
		edit_button.button_pressed = true 

func _on_delete_toggled(is_pressed: bool):
	if is_pressed:
		switch_mode(EditorMode.DELETE)
	else:
		delete_button.button_pressed = true

func select_item(index: int):
	current_selected_index = index
	
	# Automatically switch to PLACE mode, which un-toggles Edit/Delete buttons
	switch_mode(EditorMode.PLACE)
	
	# Setup the visual preview
	var temp_instance = item_catalog[index].instantiate()
	if temp_instance is Sprite2D:
		preview_sprite.texture = temp_instance.texture
	elif temp_instance.has_node("Sprite2D"):
		preview_sprite.texture = temp_instance.get_node("Sprite2D").texture
	temp_instance.queue_free()
	preview_sprite.visible = true

# --- Input Handling based on Current Mode ---
func _unhandled_input(event):
	if is_ui_hovered:
		return

	match current_mode:
		EditorMode.EDIT:
			handle_edit_input(event)
		EditorMode.DELETE:
			handle_delete_input(event)
		EditorMode.PLACE:
			handle_place_input(event)

# --- Mode Actions ---
func handle_edit_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var clicked_obj = get_object_at(get_global_mouse_position())
			if clicked_obj:
				# Left click on object: Edit/Drag it
				dragging_object = clicked_obj
			else:
				# Left click on empty space: Scroll/Pan camera
				is_panning = true
		else:
			is_panning = false
			dragging_object = null
			
	if event is InputEventMouseMotion:
		if is_panning:
			camera.global_position -= event.relative
		elif dragging_object:
			# Drag object and snap it to grid
			var mouse_pos = get_global_mouse_position()
			var snapped_pos = (mouse_pos / grid_size).floor() * grid_size
			dragging_object.global_position = snapped_pos

func handle_delete_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target = get_object_at(get_global_mouse_position())
		if target:
			target.queue_free()

func handle_place_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		place_object(preview_sprite.global_position)

# --- Helpers ---
func get_object_at(pos: Vector2) -> Node2D:
	# 1. Ask Godot's physics engine what is exactly at the mouse position
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true  # CRITICAL: Ensures we can click Area2Ds
	query.collide_with_bodies = true # Ensures we can click Static/Rigid/Character bodies
	
	var results = space_state.intersect_point(query)
	
	if results.size() > 0:
		# We clicked inside a collision shape! 
		# results[0].collider is the Area2D or PhysicsBody2D we hit.
		var clicked_collider = results[0].collider
		
		# Trace up the tree to find the root object inside 'PlacedObjects'
		var current_node = clicked_collider
		while current_node != null and current_node.get_parent() != placed_objects_node:
			current_node = current_node.get_parent()
			
		# If we found the root placed object, return it
		if current_node and current_node.get_parent() == placed_objects_node:
			return current_node

	# 2. Fallback: If the object doesn't have a collision shape yet, 
	# fall back to a slightly wider distance check so it doesn't break.
	var snapped_pos = (pos / grid_size).floor() * grid_size
	for child in placed_objects_node.get_children():
		if not child.is_queued_for_deletion() and child.global_position.distance_to(snapped_pos) < 32:
			return child
			
	return null

func place_object(pos: Vector2):
	if get_object_at(pos) != null:
		return # Spot occupied

	var scene_to_place = item_catalog[current_selected_index]
	var instance = scene_to_place.instantiate()
	instance.global_position = pos
	instance.set_meta("catalog_index", current_selected_index)
	placed_objects_node.add_child(instance)

func setup_ui_catalog():
	for i in range(item_catalog.size()):
		var btn = Button.new()
		btn.text = "Item " + str(i)
		btn.pressed.connect(func(): select_item(i))
		grid_container.add_child(btn)

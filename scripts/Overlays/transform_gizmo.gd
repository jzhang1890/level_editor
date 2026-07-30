extends Node2D

# Custom signals to tell editor something was transformed for undo/redo
signal transform_started
signal transform_ended

var is_toggled_on: bool = false # Defaults to off

var target_objects: Array[Node2D] = []
var is_scaling: bool = false
var is_rotating: bool = false
var is_scaling_x: bool = false
var is_scaling_y: bool = false
var is_skewing: bool = false
var is_skewing_y: bool = false

var group_center: Vector2 = Vector2.ZERO
var initial_mouse_pos: Vector2 = Vector2.ZERO
var initial_scales: Array[Vector2] = []
var initial_rotations: Array[float] = []
var initial_positions: Array[Vector2] = []
var initial_skews: Array[float] = []
# Godot doesn't have y skew so this is data for multiple transformations to fake Y skew
var initial_transforms: Array[Transform2D] = []

var initial_group_center: Vector2 = Vector2.ZERO

var initial_gizmo_rotation: float = 0.0
var bounding_rect: Rect2

@onready var scale_handle: Area2D = $ScaleHandle
@onready var rotate_handle: Area2D = $RotateHandle
@onready var scale_x_handle: Area2D = $ScaleXHandle
@onready var scale_y_handle: Area2D = $ScaleYHandle
@onready var skew_handle: Area2D = $SkewHandle
@onready var skew_y_handle: Area2D = $SkewYHandle

func toggle_visibility() -> void:
	is_toggled_on = not is_toggled_on
	
	# Show the gizmo if toggled on while objects are already selected
	if is_toggled_on and not target_objects.is_empty():
		visible = true
		_calculate_bounding_box()
	else:
		visible = false

func _ready() -> void:
	# Connect the handles to detect mouse clicks
	scale_handle.input_event.connect(_on_scale_handle_input)
	rotate_handle.input_event.connect(_on_rotate_handle_input)
	
	# Connect directional handles
	scale_x_handle.input_event.connect(_on_scale_x_handle_input)
	scale_y_handle.input_event.connect(_on_scale_y_handle_input)
	
	# Connect skewers
	skew_handle.input_event.connect(_on_skew_handle_input)
	skew_y_handle.input_event.connect(_on_skew_y_handle_input)
	
	visible = false

func _process(_delta: float) -> void:
	if not visible or target_objects.is_empty():
		return
		
	var cam = get_viewport().get_camera_2d()
	if cam:
		# 1. Calculate the exact opposite of the camera's current zoom
		# Divide it by 2 so the handles are smaller
		var inverse_zoom = Vector2(1.0 / cam.zoom.x, 1.0 / cam.zoom.y)/2
		
		# 2. Scale all the handles by that inverse amount
		scale_handle.scale = inverse_zoom
		rotate_handle.scale = inverse_zoom
		scale_x_handle.scale = inverse_zoom
		scale_y_handle.scale = inverse_zoom
		skew_handle.scale = inverse_zoom
		skew_y_handle.scale = inverse_zoom
		
		# 3. Scale the physical distance of offset handles so they don't overlap the box when zoomed out
		var offset_dist = 48.0 * inverse_zoom.x
		var local_center_x = bounding_rect.position.x + (bounding_rect.size.x / 2.0)
		var max_x = bounding_rect.position.x + bounding_rect.size.x
		var min_y = bounding_rect.position.y
		var max_y = bounding_rect.position.y + bounding_rect.size.y
		
		rotate_handle.position = Vector2(local_center_x, min_y - offset_dist)
		skew_handle.position = Vector2(local_center_x + offset_dist, min_y - offset_dist)
		skew_y_handle.position = Vector2(max_x + offset_dist, (min_y + max_y) / 2.0 - offset_dist)
		
		# Force the box to redraw so the lines also adjust to the zoom
		queue_redraw()

# This is called by your main script whenever selection changes
func update_selection(selected: Array[Node2D]) -> void:
	# Add .duplicate() to safely isolate the data
	target_objects = selected.duplicate()
	
	# If no objects selected or not toggled on, don't show the gizmo
	if target_objects.is_empty() or not is_toggled_on:
		visible = false
		return
		
	visible = true
	
	# Smart Rotation: Hug single objects or reset for groups
	if target_objects.size() == 1:
		global_rotation = deg_to_rad(target_objects[0].rotation_degrees)
	else:
		global_rotation = 0.0
		
	_calculate_bounding_box()

func _calculate_bounding_box() -> void:
	if target_objects.is_empty():
		return

	# 1. Calculate the true center of the group in world space
	var center = Vector2.ZERO
	for obj in target_objects:
		center += obj.global_position
	center /= target_objects.size()
	
	group_center = center
	global_position = group_center

	# 2. Find min and max in local space while respecting current rotation
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for obj in target_objects:
		var local_pos = to_local(obj.global_position)
		
		# Find the real size of the object's Sprite
		var base_extents = Vector2(32.0, 32.0) # Includes safe fallback just in case
		
		# Search inside the collision object for its visual sprite
		for child in obj.get_children():
			if child is Sprite2D and child.texture:
				# Get the true dimensions of the image, account for any sprite-level scaling, and cut it in half for the radius
				base_extents = (child.texture.get_size() * child.scale) / 2.0
				break
		
		# Apply the dynamic padding using the newly measured extents
		var padding_x = base_extents.x * abs(obj.scale.x)
		var padding_y = base_extents.y * abs(obj.scale.y)
		
		# Apply the dynamic padding directly to the min/max checks
		if local_pos.x - padding_x < min_x: min_x = local_pos.x - padding_x
		if local_pos.x + padding_x > max_x: max_x = local_pos.x + padding_x
		if local_pos.y - padding_y < min_y: min_y = local_pos.y - padding_y
		if local_pos.y + padding_y > max_y: max_y = local_pos.y + padding_y

	var box_width = max_x - min_x
	var box_height = max_y - min_y

	# 3. Store the box for the _draw() function
	bounding_rect = Rect2(min_x, min_y, box_width, box_height)

	# 4. Position scale handle at UPPER-RIGHT corner
	scale_handle.position = Vector2(max_x, min_y)

	# 5. Position rotate handle Top-Center, offset 48px above the box
	var local_center_x = (min_x + max_x) / 2.0
	rotate_handle.position = Vector2(local_center_x, min_y - 48.0)
	
	# 6. Position X handle at RIGHT-MIDDLE
	scale_x_handle.position = Vector2(max_x, (min_y + max_y) / 2.0)
	
	# 7. Position Y handle at TOP-MIDDLE
	scale_y_handle.position = Vector2(local_center_x, min_y)
	
	# 8. Position Skew handle offset from Top-Center
	skew_handle.position = Vector2(local_center_x + 48.0, min_y - 48.0)
	
	# 9. Position vertical Skew handle offset from Right-Middle
	skew_y_handle.position = Vector2(max_x + 48.0, (min_y + max_y) / 2.0 - 48.0)

	queue_redraw()
	
func _draw() -> void:
	if target_objects.is_empty():
		return
		
	var line_thickness = 2.0
	var cam = get_viewport().get_camera_2d()
	if cam:
		# Divide the base thickness by the zoom to keep it visually constant
		line_thickness /= cam.zoom.x
		
	# Draw outline using the saved local rect
	draw_rect(bounding_rect, Color(0.2, 0.6, 1.0, 0.8), false, line_thickness)
	
	# Draw the line up to the rotate handle
	var top_center = Vector2(rotate_handle.position.x, bounding_rect.position.y)
	draw_line(top_center, rotate_handle.position, Color(0.2, 0.6, 1.0, 0.8), line_thickness)

func _unhandled_input(event: InputEvent) -> void:
	# If the user lets go of the mouse, stop all dragging
	if event is InputEventMouseButton and not event.pressed:
		
		# ONLY trigger the release logic if we were actually using the gizmo
		if is_scaling or is_rotating or is_scaling_x or is_scaling_y or is_skewing or is_skewing_y:
			get_viewport().set_input_as_handled()
			
			transform_ended.emit()
			
			is_scaling = false
			is_rotating = false
			is_scaling_x = false
			is_scaling_y = false
			is_skewing = false
			is_skewing_y = false
			
			# Unlock the camera
			var cam = get_viewport().get_camera_2d()
			if cam:
				cam.set_process_unhandled_input(true)
				cam.set_process_input(true)
				cam.set_process(true)
		
	# Start the transofrm
	if event is InputEventMouseMotion:
		if is_scaling:
			get_viewport().set_input_as_handled()
			_apply_scale()
		elif is_scaling_x:
			get_viewport().set_input_as_handled()
			_apply_scale_x()
		elif is_scaling_y:
			get_viewport().set_input_as_handled()
			_apply_scale_y()
		elif is_rotating:
			get_viewport().set_input_as_handled()
			_apply_rotation()
		elif is_skewing:
			get_viewport().set_input_as_handled()
			_apply_skew()
		elif is_skewing_y:
			get_viewport().set_input_as_handled()
			_apply_skew_y()

func _apply_scale() -> void:
	var current_mouse_pos = get_global_mouse_position()
	
	# Use absolute distance to lock aspect ratio perfectly 
	var initial_dist = initial_mouse_pos.distance_to(initial_group_center)
	var current_dist = current_mouse_pos.distance_to(initial_group_center)
	
	# Safety check
	if initial_dist > 0.01:
		var ratio = current_dist / initial_dist
		var scale_ratio = Vector2(ratio, ratio)
		
		for i in range(target_objects.size()):
			var obj = target_objects[i]
			
			obj.scale = initial_scales[i] * scale_ratio
			
			var obj_initial_offset = initial_positions[i] - initial_group_center
			obj.global_position = initial_group_center + (obj_initial_offset * scale_ratio)
			
	_calculate_bounding_box()

func _apply_rotation() -> void:
	var current_mouse_pos = get_global_mouse_position()
	
	var initial_angle = (initial_mouse_pos - initial_group_center).angle()
	var current_angle = (current_mouse_pos - initial_group_center).angle()
	var angle_diff = current_angle - initial_angle
	
	# Spin the Gizmo and its handles instantly
	global_rotation = initial_gizmo_rotation + angle_diff
	
	for i in range(target_objects.size()):
		var obj = target_objects[i]
		
		var new_rot = initial_rotations[i] + rad_to_deg(angle_diff)
		obj.rotation_degrees = new_rot
		obj.set_meta("base_rotation", new_rot)
		
		var obj_initial_offset = initial_positions[i] - initial_group_center
		var rotated_offset = obj_initial_offset.rotated(angle_diff)
		
		obj.global_position = initial_group_center + rotated_offset
		
	_calculate_bounding_box()
	
func _on_scale_handle_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Stop the click from reaching the Editor Root
			get_viewport().set_input_as_handled() 
			
			# Tell the Editor Root to take a snapshot so it can be undid and redone
			transform_started.emit()
			
			# Lock the camera 
			var cam = get_viewport().get_camera_2d()
			if cam:
				cam.set_process_unhandled_input(false)
				cam.set_process_input(false)
				cam.set_process(false)
			
			is_scaling = true
			
			# Lock the anchor point so it cannot drift during math
			initial_group_center = group_center
			
			initial_mouse_pos = get_global_mouse_position()
			
			# Snapshot the starting scales AND positions
			initial_scales.clear()
			initial_positions.clear()
			for obj in target_objects:
				initial_scales.append(obj.scale)
				initial_positions.append(obj.global_position)

func _on_rotate_handle_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Detect left click on the rotate dot
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			get_viewport().set_input_as_handled() 
			
			# Tell the Editor Root to take a snapshot so it can be undid and redone
			transform_started.emit()
			
			var cam = get_viewport().get_camera_2d()
			if cam:
				cam.set_process_unhandled_input(false)
				cam.set_process_input(false)
				cam.set_process(false)
				
			is_rotating = true
			
			# Lock the anchor point so it cannot drift during math
			initial_group_center = group_center
			
			initial_mouse_pos = get_global_mouse_position()
			
			# Snapshot the Gizmo's rotation
			initial_gizmo_rotation = global_rotation
			
			initial_rotations.clear()
			initial_positions.clear()
			for obj in target_objects:
				initial_rotations.append(obj.rotation_degrees)
				initial_positions.append(obj.global_position)
				
func _apply_scale_x() -> void:
	var current_mouse_pos = get_global_mouse_position()
	
	# Project the vector onto the gizmo's local axes by undoing its rotation
	var initial_vec = (initial_mouse_pos - initial_group_center).rotated(-global_rotation)
	var current_vec = (current_mouse_pos - initial_group_center).rotated(-global_rotation)
	
	# Prevent dividing by zero
	if abs(initial_vec.x) > 0.01:
		var ratio = current_vec.x / initial_vec.x
		var scale_ratio = Vector2(ratio, 1.0) # Stretch X, lock Y
		
		for i in range(target_objects.size()):
			var obj = target_objects[i]
			obj.scale = initial_scales[i] * scale_ratio
			
			# Update position based on scale change
			var obj_initial_offset = initial_positions[i] - initial_group_center
			var local_offset = obj_initial_offset.rotated(-global_rotation)
			obj.global_position = initial_group_center + (local_offset * scale_ratio).rotated(global_rotation)
			
	_calculate_bounding_box()

func _apply_scale_y() -> void:
	var current_mouse_pos = get_global_mouse_position()
	
	# Project the vector onto the gizmo's local axes by undoing its rotation
	var initial_vec = (initial_mouse_pos - initial_group_center).rotated(-global_rotation)
	var current_vec = (current_mouse_pos - initial_group_center).rotated(-global_rotation)
	
	# Prevent dividing by zero
	if abs(initial_vec.y) > 0.01:
		var ratio = current_vec.y / initial_vec.y
		var scale_ratio = Vector2(1.0, ratio) # Lock X, stretch Y
		
		for i in range(target_objects.size()):
			var obj = target_objects[i]
			obj.scale = initial_scales[i] * scale_ratio
			
			var obj_initial_offset = initial_positions[i] - initial_group_center
			var local_offset = obj_initial_offset.rotated(-global_rotation)
			obj.global_position = initial_group_center + (local_offset * scale_ratio).rotated(global_rotation)
			
	_calculate_bounding_box()

func _on_scale_x_handle_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled() 
		transform_started.emit()
		
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.set_process_unhandled_input(false)
			cam.set_process_input(false)
			cam.set_process(false)
			
		is_scaling_x = true
		initial_group_center = group_center
		initial_mouse_pos = get_global_mouse_position()
		
		initial_scales.clear()
		initial_positions.clear()
		for obj in target_objects:
			initial_scales.append(obj.scale)
			initial_positions.append(obj.global_position)

func _on_scale_y_handle_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled() 
		transform_started.emit()
		
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.set_process_unhandled_input(false)
			cam.set_process_input(false)
			cam.set_process(false)
			
		is_scaling_y = true
		initial_group_center = group_center
		initial_mouse_pos = get_global_mouse_position()
		
		initial_scales.clear()
		initial_positions.clear()
		for obj in target_objects:
			initial_scales.append(obj.scale)
			initial_positions.append(obj.global_position)
			
func _apply_skew() -> void:
	var current_mouse_pos = get_global_mouse_position()
	
	# Convert the mouse movement into the Gizmo's local rotated space
	var local_initial = (initial_mouse_pos - initial_group_center).rotated(-global_rotation)
	var local_current = (current_mouse_pos - initial_group_center).rotated(-global_rotation)
	
	# Calculate horizontal difference and apply a sensitivity multiplier
	var skew_diff = (local_current.x - local_initial.x) * 0.01 
	
	for i in range(target_objects.size()):
		var obj = target_objects[i]
		# Apply the skew
		obj.skew = initial_skews[i] + skew_diff
			
	_calculate_bounding_box()

func _on_skew_handle_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled() 
		transform_started.emit()
		
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.set_process_unhandled_input(false)
			cam.set_process_input(false)
			cam.set_process(false)
			
		is_skewing = true
		initial_group_center = group_center
		initial_mouse_pos = get_global_mouse_position()
		
		initial_skews.clear()
		for obj in target_objects:
			initial_skews.append(obj.skew)
			
func _apply_skew_y() -> void:
	var current_mouse_pos = get_global_mouse_position()
	
	var local_initial = (initial_mouse_pos - initial_group_center).rotated(-global_rotation)
	var local_current = (current_mouse_pos - initial_group_center).rotated(-global_rotation)
	
	# Calculate the vertical drag offset
	var skew_diff = (local_current.y - local_initial.y) * 0.01
	
	# Build the vertical shear matrix
	var shear_matrix = Transform2D(Vector2(1, skew_diff), Vector2(0, 1), Vector2.ZERO)
	
	# Build the matrices to convert to and from the Gizmo's rotated local space
	var gizmo_rot_matrix = Transform2D(global_rotation, Vector2.ZERO)
	var inv_gizmo_rot = Transform2D(-global_rotation, Vector2.ZERO)
	
	for i in range(target_objects.size()):
		var obj = target_objects[i]
		
		# 1. Take initial transform and remove the origin (position)
		var t = initial_transforms[i]
		t.origin = Vector2.ZERO
		
		# 2. Apply the matrix multiplication: GizmoRot * Shear * InvGizmoRot * ObjectTransform
		t = gizmo_rot_matrix * shear_matrix * inv_gizmo_rot * t
		
		# 3. Push the auto-decomposed properties back to Godot
		obj.rotation = t.get_rotation()
		obj.scale = t.get_scale()
		obj.skew = t.get_skew()
		
		# 4. Adjust the visual position offset so groups slide together correctly
		var obj_initial_offset = initial_positions[i] - initial_group_center
		var local_offset = obj_initial_offset.rotated(-global_rotation)
		
		local_offset.y += local_offset.x * skew_diff
		
		obj.global_position = initial_group_center + local_offset.rotated(global_rotation)
		
	_calculate_bounding_box()

func _on_skew_y_handle_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled() 
		transform_started.emit()
		
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.set_process_unhandled_input(false)
			cam.set_process_input(false)
			cam.set_process(false)
			
		is_skewing_y = true
		initial_group_center = group_center
		initial_mouse_pos = get_global_mouse_position()
		
		initial_transforms.clear()
		initial_positions.clear()
		for obj in target_objects:
			# Capture the pure transform without the coordinate position
			var t = obj.global_transform
			t.origin = Vector2.ZERO
			initial_transforms.append(t)
			initial_positions.append(obj.global_position)
				

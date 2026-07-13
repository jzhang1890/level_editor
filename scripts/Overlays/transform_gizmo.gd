extends Node2D

var target_objects: Array[CollisionObject2D] = []
var is_scaling: bool = false
var is_rotating: bool = false

var group_center: Vector2 = Vector2.ZERO
var initial_mouse_pos: Vector2 = Vector2.ZERO
var initial_scales: Array[Vector2] = []
var initial_rotations: Array[float] = []
var initial_positions: Array[Vector2] = []

var initial_group_center: Vector2 = Vector2.ZERO

var initial_gizmo_rotation: float = 0.0
var bounding_rect: Rect2

@onready var scale_handle: Area2D = $ScaleHandle
@onready var rotate_handle: Area2D = $RotateHandle

func _ready() -> void:
	# Connect the handles to detect mouse clicks
	scale_handle.input_event.connect(_on_scale_handle_input)
	rotate_handle.input_event.connect(_on_rotate_handle_input)
	visible = false

# This is called by your main script whenever selection changes
func update_selection(selected: Array[CollisionObject2D]) -> void:
	# Add .duplicate() to safely isolate the data
	target_objects = selected.duplicate()
	if target_objects.is_empty():
		visible = false
		return
		
	visible = true
	
	# Smart Rotation: Hug single objects perfectly, or reset for groups
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

	# 2. Find min and max in LOCAL space (respecting our current rotation)
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for obj in target_objects:
		var local_pos = to_local(obj.global_position)
		if local_pos.x < min_x: min_x = local_pos.x
		if local_pos.x > max_x: max_x = local_pos.x
		if local_pos.y < min_y: min_y = local_pos.y
		if local_pos.y > max_y: max_y = local_pos.y

	var padding = 32.0
	min_x -= padding
	max_x += padding
	min_y -= padding
	max_y += padding

	var box_width = max_x - min_x
	var box_height = max_y - min_y

	# 3. Store the box for the _draw() function
	bounding_rect = Rect2(min_x, min_y, box_width, box_height)

	# 4. Position scale handle at UPPER-RIGHT corner
	scale_handle.position = Vector2(max_x, min_y)

	# 5. Position rotate handle Top-Center, offset 32px above the box
	var local_center_x = (min_x + max_x) / 2.0
	rotate_handle.position = Vector2(local_center_x, min_y - 32.0)

	queue_redraw()

func _draw() -> void:
	if target_objects.is_empty():
		return
		
	# Draw the fill and outline using the saved local rect
	draw_rect(bounding_rect, Color(0.2, 0.6, 1.0, 0.2), true)
	draw_rect(bounding_rect, Color(0.2, 0.6, 1.0, 0.8), false, 2.0)
	
	# Draw the line up to the rotate handle
	var top_center = Vector2(rotate_handle.position.x, bounding_rect.position.y)
	draw_line(top_center, rotate_handle.position, Color(0.2, 0.6, 1.0, 0.8), 2.0)

func _unhandled_input(event: InputEvent) -> void:
	# If the user lets go of the mouse, stop all dragging
	if event is InputEventMouseButton and not event.pressed:
		is_scaling = false
		is_rotating = false
		
		# --- NEW: Unlock the camera ---
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.set_process_unhandled_input(true)
			cam.set_process_input(true)
			cam.set_process(true)
		
	if event is InputEventMouseMotion:
		if is_scaling:
			_apply_scale()
		elif is_rotating:
			_apply_rotation()

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
	
	# NEW: Spin the Gizmo and its handles instantly!
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
			# --- FIX: Stop the click from reaching the Editor Root! ---
			get_viewport().set_input_as_handled() 
			
			# --- NEW: Lock the camera ---
			var cam = get_viewport().get_camera_2d()
			if cam:
				cam.set_process_unhandled_input(false)
				cam.set_process_input(false)
				cam.set_process(false)
			
			is_scaling = true
			
			# --- NEW: Lock the anchor point so it cannot drift during math ---
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
			
			var cam = get_viewport().get_camera_2d()
			if cam:
				cam.set_process_unhandled_input(false)
				cam.set_process_input(false)
				cam.set_process(false)
				
			is_rotating = true
			
			# --- NEW: Lock the anchor point so it cannot drift during math ---
			initial_group_center = group_center
			
			initial_mouse_pos = get_global_mouse_position()
			
			# NEW: Snapshot the Gizmo's rotation
			initial_gizmo_rotation = global_rotation
			
			initial_rotations.clear()
			initial_positions.clear()
			for obj in target_objects:
				initial_rotations.append(obj.rotation_degrees)
				initial_positions.append(obj.global_position)

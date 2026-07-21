extends Node

# The main editor node
@onready var editor: Node2D = get_parent()

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
const MAX_UNDO_STEPS: int = 100
var drag_start_state: Array = []

# 1. Takes an array of objects and converts them to pure dictionary data
func serialize_objects(objects: Array) -> Array:
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
			"skew": obj.skew,
			"layer": obj.get_meta("layer", 1),
			"unique_id": obj.get_meta("unique_id", ""),
			"tree_index": obj.get_index(), 
			"color_channel": obj.get_meta("color_channel", 0)
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


# UNDO/REDO HELPER FUNCTIONS (Adjusted with 'editor.' routing)

func remove_objects_by_id(data_array: Array) -> void:
	var object_lookup = {}
	for chunk_id in editor.level_chunks:
		for child in editor.level_chunks[chunk_id]:
			if is_instance_valid(child) and child.has_meta("unique_id"):
				object_lookup[child.get_meta("unique_id")] = child
				
	for item in data_array:
		var obj = object_lookup.get(item["unique_id"])
		if obj:
			if editor.selected_objects.has(obj): editor.change_selection(obj, true) 
			obj.queue_free()

func recreate_objects(data_array: Array) -> void:
	editor.change_selection(null, false)
	var newly_created = []
	
	for item in data_array:
		var resource = load(item["scene_path"])
		if resource:
			var new_object = resource.instantiate()
			new_object.global_position = item["global_position"]
			new_object.rotation_degrees = item["rotation_degrees"]
			new_object.scale = item["scale"]
			new_object.skew = item.get("skew", 0.0)
			new_object.set_meta("base_rotation", item["base_rotation"])
			new_object.set_meta("layer", item["layer"])
			new_object.z_index = -item["layer"]
			
			var loaded_channel = item.get("color_channel", 0)
			new_object.set_meta("color_channel", loaded_channel)
			new_object.modulate = Global.get_channel_color(loaded_channel)
			new_object.set_meta("unique_id", item["unique_id"])
			
			var chunk_id = int(floor(new_object.global_position.y / editor.CHUNK_HEIGHT))

			if not editor.level_chunks.has(chunk_id):
				editor.level_chunks[chunk_id] = []

			editor.room_canvas.add_child(new_object)
			
			if item.has("tree_index"):
				editor.room_canvas.move_child(new_object, item["tree_index"])
			
			editor.level_chunks[chunk_id].append(new_object)
			
			if chunk_id not in editor.active_chunks:
				new_object.process_mode = Node.PROCESS_MODE_DISABLED
				new_object.visible = false

			newly_created.append(new_object)
			
	for obj in newly_created:
		editor.selected_objects.append(obj)
		if obj.has_method("set_highlight"):
			obj.set_highlight(true)
			
	if editor.selection_menu:
		editor.selection_menu.visible = editor.selected_objects.size() > 0
		
	if editor.has_node("Foreground/TransformGizmo"):
		editor.get_node("Foreground/TransformGizmo").update_selection(editor.selected_objects)

func apply_object_state(data_array: Array) -> void:
	var object_lookup = {}
	for chunk_id in editor.level_chunks:
		for child in editor.level_chunks[chunk_id]:
			if is_instance_valid(child) and child.has_meta("unique_id"):
				object_lookup[child.get_meta("unique_id")] = child

	for item in data_array:
		var obj = object_lookup.get(item["unique_id"])
		if obj:
			obj.global_position = item["global_position"]
			obj.rotation_degrees = item["rotation_degrees"]
			obj.scale = item["scale"]
			obj.skew = item.get("skew", 0.0)
			obj.set_meta("base_rotation", item["base_rotation"])
			obj.set_meta("layer", item["layer"])
			obj.z_index = -item["layer"]
			
			var loaded_channel = item.get("color_channel", 0)
			obj.set_meta("color_channel", loaded_channel)
			obj.modulate = Global.get_channel_color(loaded_channel)

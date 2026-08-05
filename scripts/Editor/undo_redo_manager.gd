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
		#  Grabs all the metadata from the object
		var all_meta = {}
		for meta_key in obj.get_meta_list():
			var meta_value = obj.get_meta(meta_key)
			if typeof(meta_value) == TYPE_ARRAY:
				all_meta[meta_key] = meta_value.duplicate()
			else:
				all_meta[meta_key] = meta_value
		data_array.append({
			"scene_path": obj.scene_file_path,
			"global_position": obj.global_position,
			"rotation_degrees": obj.rotation_degrees,
			"base_rotation": obj.get_meta("base_rotation", obj.rotation_degrees),
			"scale": obj.scale,
			"skew": obj.skew,
			"unique_id": obj.get_meta("unique_id", ""),
			"tree_index": obj.get_index(), 
			"saved_metadata": all_meta,
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
		"color_change": apply_global_color(action["old_data"])
		
	editor.update_trigger_visuals()
	
# 4. Redo Logic
func redo_action() -> void:
	if redo_stack.is_empty(): return
	var action = redo_stack.pop_back()
	undo_stack.append(action)
	
	match action["type"]:
		"place": recreate_objects(action["new_data"])
		"delete": remove_objects_by_id(action["old_data"])
		"edit": apply_object_state(action["new_data"])
		"color_change": apply_global_color(action["new_data"])

	editor.update_trigger_visuals()

# UNDO/REDO HELPER FUNCTIONS

func remove_objects_by_id(data_array: Array) -> void:
	# Create a temporary dictionary for O(1) lookups 
	var fast_selection_check = {}
	for sel in editor.selected_objects:
		fast_selection_check[sel] = true
				
	for item in data_array:
		var uid = item["unique_id"]
		# Direct O(1) lookup
		var obj = editor.object_registry.get(uid) 
		if obj:
			if fast_selection_check.has(obj): editor.change_selection(obj, true)
			# Unregister and destroy
			editor.object_registry.erase(uid)
			obj.queue_free()

func recreate_objects(data_array: Array) -> void:
	editor.change_selection(null, false)
	var newly_created = []
	
	for item in data_array:
		var resource = load(item["scene_path"])
		if resource:
			var new_object = resource.instantiate()
			if item.has("saved_metadata"):
				for meta_key in item["saved_metadata"]:
					var meta_value = item["saved_metadata"][meta_key]
					if typeof(meta_value) == TYPE_ARRAY:
						new_object.set_meta(meta_key, meta_value.duplicate())
					else:
						new_object.set_meta(meta_key, meta_value)
			new_object.global_position = item["global_position"]
			new_object.rotation_degrees = item["rotation_degrees"]
			new_object.scale = item["scale"]
			new_object.skew = item.get("skew", 0.0)
			new_object.set_meta("base_rotation", item["base_rotation"])

			var loaded_layer = new_object.get_meta("layer", 1)
			var loaded_z_layer = new_object.get_meta("z_layer", 0)
			var loaded_z = new_object.get_meta("custom_z_order", 2)
			
			new_object.z_index = (loaded_z_layer * 300) + loaded_z
			
			var loaded_channel = new_object.get_meta("color_channel", 0)
			
			# OPACITY ROUTING 
			var target_color = Global.get_channel_color(loaded_channel)
			if new_object is Sprite2D:
				if editor.current_layer != 0 and editor.current_layer != loaded_layer:
					target_color.a = 0.05
				new_object.modulate = target_color
			else: 
				var sprite = new_object.get_node_or_null("Sprite2D")
				if sprite:
					sprite.modulate = target_color 
				if editor.current_layer != 0 and editor.current_layer != loaded_layer:
					new_object.modulate = Color(1, 1, 1, 0.05) 
				else: 
					new_object.modulate = Color(1, 1, 1, 1.0) 

			new_object.set_meta("unique_id", item["unique_id"])
			
			# Register the recreated object
			editor.object_registry[item["unique_id"]] = new_object
			
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
	# Create a temporary dictionary for O(1) lookups
	var fast_selection_check = {}
	for sel in editor.selected_objects:
		fast_selection_check[sel] = true

	for item in data_array:
		# O(1) lookup
		var obj = editor.object_registry.get(item["unique_id"]) 
		if obj:
			if item.has("saved_metadata"):
				for meta_key in item["saved_metadata"]:
					# Skip color-related metadata so physical moves don't overwrite color edits
					if meta_key in ["color_channel", "trigger_color"]:
						continue
					
					var meta_value = item["saved_metadata"][meta_key]
					if typeof(meta_value) == TYPE_ARRAY:
						obj.set_meta(meta_key, meta_value.duplicate())
					else:
						obj.set_meta(meta_key, meta_value)
			obj.global_position = item["global_position"]
			obj.rotation_degrees = item["rotation_degrees"]
			obj.scale = item["scale"]
			obj.skew = item.get("skew", 0.0)
			obj.set_meta("base_rotation", item["base_rotation"])
			
			var loaded_layer = obj.get_meta("layer", 1)
			var loaded_z_layer = obj.get_meta("z_layer", 0)
			var loaded_z = obj.get_meta("custom_z_order", 2)
			
			obj.z_index = (loaded_z_layer * 300) + loaded_z
			
			var loaded_channel = obj.get_meta("color_channel", 0)
			
			# OPACITY ROUTING 
			var target_color = Global.get_channel_color(loaded_channel)
			if obj is Sprite2D:
				if editor.current_layer != 0 and editor.current_layer != loaded_layer:
					target_color.a = 0.05
				obj.modulate = target_color
			else: 
				var sprite = obj.get_node_or_null("Sprite2D")
				if sprite:
					sprite.modulate = target_color 
				if editor.current_layer != 0 and editor.current_layer != loaded_layer:
					obj.modulate = Color(1, 1, 1, 0.05) 
				else: 
					obj.modulate = Color(1, 1, 1, 1.0) 
			
			# Re-apply the highlight if it's currently selected
			if fast_selection_check.has(obj) and obj.has_method("set_highlight"):
				obj.set_highlight(true)
			# Place the gizmo at correct location
	if editor.has_node("Foreground/TransformGizmo"):
		editor.get_node("Foreground/TransformGizmo").update_selection(editor.selected_objects)

func apply_global_color(data_array: Array) -> void:
	var channel = data_array[0]["channel"]
	var target_color = data_array[0]["color"]
	
	# Route the data back to the editor variables
	editor.current_editing_channel = channel
	editor.color_picker_btn.color = target_color
	
	# Re-run the existing color update function to paint the objects
	editor._on_picker_color_changed(target_color)

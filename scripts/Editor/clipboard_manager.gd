extends Node

@onready var editor: Node2D = get_parent()

# Clipboard for Copy/Paste 
var clipboard: Array[Dictionary] = []

func copy_selection() -> void:
	# Clear the old clipboard
	clipboard.clear()
	
	# Filter out any deleted/freed objects before sorting
	var sorted_selection = []
	for obj in editor.selected_objects:
		if is_instance_valid(obj):
			sorted_selection.append(obj)
	
	# Sort by visual tree index instead of creation ID
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
				"skew": obj.skew,
				"layer": obj.get_meta("layer", 1),
				"color_channel": obj.get_meta("color_channel", 0)
			}
			clipboard.append(item_data)

func paste_clipboard() -> void:
	if clipboard.is_empty():
		return
		
	# 1. Drop the currently selected objects
	editor.change_selection(null, false)
	
	var new_selection: Array[Node2D] = []
	
	# 2. Build the new objects from the clipboard data
	for item in clipboard:
		var resource = load(item["scene_path"])
		if resource:
			var new_object = resource.instantiate()
			
			# Offset the position by 1 grid blocks up
			var new_pos = item["global_position"] + Vector2(0, editor.GRID_SIZE * -1)
			new_object.global_position = new_pos
			
			# Apply visual transforms
			new_object.rotation_degrees = item["rotation_degrees"]
			new_object.scale = item["scale"]
			new_object.skew = item.get("skew", 0.0)
			
			# Apply metadata and layer sorting
			new_object.set_meta("base_rotation", item["base_rotation"])
			new_object.set_meta("layer", item["layer"])
			new_object.z_index = -item["layer"]
			
			# Apply Color Channel
			var loaded_channel = item.get("color_channel", 0)
			new_object.set_meta("color_channel", loaded_channel)
			new_object.modulate = Global.get_channel_color(loaded_channel)
			
			# Generate a brand new unique ID for the clone
			var unique_id = str(Time.get_ticks_usec()) + str(randi() % 1000)
			new_object.set_meta("unique_id", unique_id)
			
			# Put pasted objects into chunks
			var chunk_id = int(floor(new_object.global_position.y / editor.CHUNK_HEIGHT))

			# Create an empty array if the chunk doesn't exist
			if not editor.level_chunks.has(chunk_id):
				editor.level_chunks[chunk_id] = []

			# Add to canvas for perfect chronological layering
			editor.room_canvas.add_child(new_object)
			editor.level_chunks[chunk_id].append(new_object)
			
			# Sleep immediately if chunk is inactive
			if chunk_id not in editor.active_chunks:
				new_object.process_mode = Node.PROCESS_MODE_DISABLED
				new_object.visible = false
			
			new_selection.append(new_object)
			
			# Update the clipboard item's position so pasting again moves it another 2 blocks
			item["global_position"] = new_pos
			
	# 3. Automatically select the newly pasted objects
	for obj in new_selection:
		# Passing 'true' simulates holding Ctrl, adding them all to the group
		editor.change_selection(obj, true)
		
	if not new_selection.is_empty():
		var pasted_state = editor.undo_manager.serialize_objects(new_selection)
		editor.undo_manager.commit_action("place", [], pasted_state)

extends Node

# The main editor node
@onready var editor: Node2D = get_parent()

# Threading variables
var save_thread: Thread

# Save path
var current_save_path: String = "user://Levels/my_new_level.json"

# Track the downloaded song ID
var current_song_id: String = ""
var current_song_name: String = "Unknown"
var current_song_artist: String = "Unknown" 

# Gives it untitled if it doesnt have a name
var current_level_name: String = "Untitled"

# Default background path
var current_bg_path: String = "res://resources/backgrounds/background1.png"

# Tab 0: Background, Tab 1: Middleground, Tab 2: Foreground
var ground_colors: Dictionary = {
	0: "ffffffff", 
	1: "ffffffff", 
	2: "ffffffff"
}

# Loading level function
func load_level(target_path: String) -> void:
	if not FileAccess.file_exists(target_path):
		print("No save file found at: ", target_path)
		return
		
	editor.change_selection(null)
	
	for child in editor.room_canvas.get_children():
		child.queue_free()
		
	var file = FileAccess.open(target_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var level_data = JSON.parse_string(json_string)
		
		# Check if the data is the Dictionary format
		if typeof(level_data) == TYPE_DICTIONARY and level_data.has("items"):
			
			# Adds the level colors using level data
			if level_data.has("colors"):
				editor.apply_level_colors(level_data["colors"])
			
			# Sets the current name using level data
			if level_data.has("level_name"):
				current_level_name = level_data["level_name"]
				print("Loading level: ", current_level_name)
			
			# Load and apply the background
			if level_data.has("background"):
				current_bg_path = level_data["background"]
				var loaded_texture = load(current_bg_path)
				if loaded_texture:
					editor.bg_rect.texture = loaded_texture
					
			# Load the song ID and trigger the audio parser
			if level_data.has("song_id"):
				current_song_id = level_data["song_id"]
				
				# Grab the name and artist if they exist in the save file
				current_song_name = level_data.get("song_name", "Unknown")
				current_song_artist = level_data.get("song_artist", "Unknown")
				
				if current_song_id != "":
					load_song_to_editor(current_song_id)
					# Tell the UI to display the loaded info
					editor.ui_layer.update_song_ui(current_song_name, current_song_artist, current_song_id)
					
			# Load and apply the ground tab colors
			if level_data.has("ground_colors"):
				# Pass the JSON directly without replacing the main dictionary
				load_ground_colors(level_data["ground_colors"])
			
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
						"layer": 1,
						"color_channel": 0,
						"groups": []
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
							"9": item_dict["skew"] = val.to_float() 
							"10": item_dict["color_channel"] = val.to_int()
							"11": 
								var parsed_groups = []
								for g_str in val.split("-"):
									if g_str != "":
										parsed_groups.append(g_str.to_int())
								item_dict["groups"] = parsed_groups
							"12": item_dict["custom_z_order"] = val.to_int()
							"13": item_dict["z_layer"] = val.to_int()
							
					# Instantiate the object using parsed dict
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
						
						# Register the loaded object so Undo/Redo can see it
						editor.object_registry[item_dict["id"]] = new_object
						
						# Apply the loaded groups array
						new_object.set_meta("groups", item_dict["groups"])
						
						# Apply skew (with a safe fallback to 0.0 for older saves)
						new_object.skew = item_dict.get("skew", 0.0)
						
						# Apply layer and Z-order data
						var loaded_layer = item_dict["layer"]
						var loaded_z_layer = item_dict.get("z_layer", 0) 
						var loaded_z_order = item_dict.get("custom_z_order", 2)

						new_object.set_meta("layer", loaded_layer)
						new_object.set_meta("z_layer", loaded_z_layer)
						new_object.set_meta("custom_z_order", loaded_z_order)

						new_object.z_index = (loaded_z_layer * 300) + loaded_z_order
						
						# Apply color channel data
						new_object.set_meta("color_channel", item_dict["color_channel"])
						# Actually physically paints the object
						new_object.modulate = Global.get_channel_color(item_dict["color_channel"])
						
						# Expand the max_layer limit
						if loaded_layer > editor.max_layer:
							editor.max_layer = loaded_layer
							
						var chunk_id = int(floor(new_object.global_position.y / editor.CHUNK_HEIGHT))

						# Create an empty array if the chunk doesn't exist
						if not editor.level_chunks.has(chunk_id):
							editor.level_chunks[chunk_id] = []

						# Add to canvas
						editor.room_canvas.add_child(new_object)
						editor.level_chunks[chunk_id].append(new_object)
						
						# Sleep immediately if chunk is inactive
						if chunk_id not in editor.active_chunks:
							new_object.process_mode = Node.PROCESS_MODE_DISABLED
							new_object.visible = false
							
	editor.update_scrollbar_bounds()
	
	# Visually updates the color box when the level finishes loading
	editor.color_picker_btn.color = Global.get_channel_color(editor.current_editing_channel)

func load_ground_colors(saved_colors: Dictionary) -> void:
	# JSON keys are always strings, so loop through them and convert back to ints
	for tab_str in saved_colors.keys():
		var tab_index = int(tab_str)
		var color_hex = saved_colors[tab_str]
		var loaded_color = Color(color_hex)
		
		# 1. Physically update the texture colors using the root's function
		editor.update_ground_color(tab_index, loaded_color)
		
		# 2. Sync the UI's memory dictionary so the color picker matches the loaded color
		editor.ui_layer.ground_colors[tab_index] = loaded_color

	# 3. Visually update the physical UI button so it doesn't show the default white
	var active_tab = editor.ui_layer.grounds_container.current_tab
	editor.ui_layer.settings_color_picker.color = editor.ui_layer.ground_colors[active_tab]

# Saving Level function
func _on_save_button_pressed() -> void:
	if not DirAccess.dir_exists_absolute("user://Levels"):
		DirAccess.make_dir_absolute("user://Levels")

	# 1. Clean up the thread if the user spams the save button
	if save_thread and save_thread.is_started():
		save_thread.wait_to_finish()

	var items_string_builder: Array[String] = []
	
	# 2. Gather data on the MAIN thread (extremely fast)
	for object in editor.room_canvas.get_children():
		if object is Node2D and object.has_meta("unique_id"):
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
			
			# 9: Skew (only if non-zero)
			if not is_zero_approx(object.skew):
				obj_parts.append("9")
				obj_parts.append(str(snapped(object.skew, 0.001)))
				
			# 10: Color Channel (only if non-zero)
			var color_channel = object.get_meta("color_channel", 0)
			if color_channel != 0:
				obj_parts.append("10")
				obj_parts.append(str(color_channel))
			
			# 11: Groups (only if the array isn't empty)
			var groups = object.get_meta("groups", [])
			if groups.size() > 0:
				obj_parts.append("11")
				var group_strings = []
				for g in groups:
					group_strings.append(str(g))
				# Join them with a hyphen so it doesn't break the comma parsing
				obj_parts.append("-".join(group_strings))
			
			# 12: Custom Z-Order 
			var custom_z = object.get_meta("custom_z_order", 2)
			obj_parts.append("12")
			obj_parts.append(str(custom_z))
			
			# 13: Z-Layer Data
			var z_layer = object.get_meta("z_layer", 0)
			obj_parts.append("13")
			obj_parts.append(str(z_layer))
			
			# Join properties with commas (e.g. "1,id,2,path,3,x,4,y")
			items_string_builder.append(",".join(obj_parts))
			
	# Join all objects with semicolons
	var compressed_items_string = ";".join(items_string_builder)
			
	# 1. Create a staging dictionary
	var colors_as_hex: Dictionary = {}
	
	# 2. Set up a for loop to go through each key
	for channel_id in Global.active_level_colors.keys():
		# 3. Grab the color and convert it to a hex string
		var raw_color: Color = Global.active_level_colors[channel_id]
		colors_as_hex[channel_id] = raw_color.to_html()
			
	var save_dict: Dictionary = {
		"level_name": current_level_name,
		"background": current_bg_path, 
		"song_id": current_song_id,
		"song_name": current_song_name,
		"song_artist": current_song_artist,
		"colors": colors_as_hex,
		"ground_colors": ground_colors,
		"items": compressed_items_string, # Single optimized string
	}
			
	# 3. Spin up the background thread
	save_thread = Thread.new()
	save_thread.start(_write_save_data_to_disk.bind(save_dict, current_save_path))
	
func _on_save_and_quit_button_pressed() -> void:
	# Just combines save and quit logic
	_on_save_button_pressed()
	_on_quit_button_pressed()
	
func _on_quit_button_pressed() -> void:
	Global.reset_colors()
	# Return to Level Browser scene
	get_tree().change_scene_to_file("res://scenes/rooms/level_details.tscn")

# Background worker function for saving data
func _write_save_data_to_disk(save_dict: Dictionary, path: String) -> void:
	# Removed the "\t" argument to minify the JSON into a single dense line 
	var json_string = JSON.stringify(save_dict) 
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		
	print("Level safely saved to: ", path)

func save_downloaded_song(song_id: String, song_title: String, song_artist: String, audio_data: PackedByteArray) -> void:
	# Update the metadata so it saves to the JSON level file
	current_song_id = song_id
	current_song_name = song_title
	current_song_artist = song_artist

	# Create the songs folder if it doesn't exist
	if not DirAccess.dir_exists_absolute("user://songs"):
		DirAccess.make_dir_absolute("user://songs")

	# Write the raw MP3 bytes to disk
	var file_path = "user://songs/" + song_id + ".mp3"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_buffer(audio_data)
		file.close()

#  Converts the saved MP3 file back into playable audio
func load_song_to_editor(song_id: String) -> void:
	var file_path = "user://songs/" + song_id + ".mp3"
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var stream = AudioStreamMP3.new()
		
		# Grab the raw bytes and assign them to the stream
		stream.data = file.get_buffer(file.get_length())
		file.close()
		
		# Locate the player node and load the stream
		var music_player = editor.get_node_or_null("LevelMusic")
		if music_player:
			music_player.stream = stream
	else:
		print("Warning: Song file not found at ", file_path)

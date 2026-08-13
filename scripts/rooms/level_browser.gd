extends Control

@onready var level_list: ItemList = $LevelList

const LEVEL_DIR: String = "user://Levels"

func _ready() -> void:
	# Makes sure the folder exists on the computer
	if not DirAccess.dir_exists_absolute(LEVEL_DIR):
		DirAccess.make_dir_absolute(LEVEL_DIR)
		
	# Fill the list
	populate_list()

func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("escape"):
			_on_back_button_pressed()

# Looks at end of file to get level name
func get_level_name_fast(target_path: String) -> String:
	var file = FileAccess.open(target_path, FileAccess.READ)
	if not file: return "Unknown Level"
	
	var file_len = file.get_length()
	# Only grab the last 1024 bytes (characters) of the file
	var read_size = min(file_len, 1024) 
	
	# Jump instantly to the bottom of the file
	file.seek(file_len - read_size)
	
	# Read only that tiny chunk into a string
	var end_text = file.get_buffer(read_size).get_string_from_utf8()
	file.close()
	
	# Instantly split the string to find the name
	var parts = end_text.split('"level_name"')
	if parts.size() > 1:
		var right_side = parts[1]
		var name_parts = right_side.split('"')
		
		# name_parts[0] will be the colon and space (e.g. ": ")
		# name_parts[1] will be the actual level name
		if name_parts.size() >= 2: 
			return name_parts[1]
			
	return "Unknown Level"

func populate_list() -> void:
	level_list.clear()
	
	var dir = DirAccess.open(LEVEL_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var full_path = LEVEL_DIR + "/" + file_name
				
				# 1. Default to the file name just in case the file is corrupted
				var display_name = file_name.replace(".json", "")
				
				# 2. Extract the name without parsing the items
				var extracted_name = get_level_name_fast(full_path)
				if extracted_name != "Unknown Level":
					display_name = extracted_name
						
				var index = level_list.add_item(display_name)
				level_list.set_item_metadata(index, full_path)
				
			file_name = dir.get_next()

func _on_level_list_item_selected(index: int) -> void:
	# 1. Grab the path from the item clicked
	var selected_path = level_list.get_item_metadata(index)
	
	# 2. Store it in Global script
	Global.level_to_load = selected_path
	
	# 3. Change to the level details page
	get_tree().call_deferred("change_scene_to_file", "res://scenes/rooms/level_details.tscn")

# New level button
func _on_create_new_button_pressed() -> void:
	# 1. Make sure the Levels folder exists
	if not DirAccess.dir_exists_absolute("user://Levels"):
		DirAccess.make_dir_absolute("user://Levels")
		
	# 2. Find a unique file name so don't accidently overwrite files
	var base_name = "untitled"
	var file_name = base_name + ".json"
	var file_path = "user://Levels/" + file_name
	var counter = 1
	
	# If "untitled.json" exists, try "untitled_1.json", "untitled_2.json", etc.
	while FileAccess.file_exists(file_path):
		file_name = base_name + "_" + str(counter) + ".json"
		file_path = "user://Levels/" + file_name
		counter += 1
		
	# 3. Create the default starting data for a new level
	var default_level_data: Dictionary = {
		"level_name": "Untitled", 
		"background": "res://resources/backgrounds/background1.png", 
		"ground_colors": {
			0: "2c6091", 
			1: "ffffffff", 
			2: "ffffffff"
		},
		"items": [] 
	}
	
	# 4. Save the new JSON file to the drive
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(default_level_data, "\t")
		file.store_string(json_string)
		file.close()
		
	# 5. Refresh the UI list so the level shows up
	populate_list()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/rooms/main_menu.tscn")

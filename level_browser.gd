extends Control

@onready var level_list: ItemList = $LevelList

const LEVEL_DIR: String = "user://Levels"

func _ready() -> void:
	# 1. Ensure the folder actually exists on the computer
	if not DirAccess.dir_exists_absolute(LEVEL_DIR):
		DirAccess.make_dir_absolute(LEVEL_DIR)
		
	# 2. Fill the list
	populate_list()

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
				
				# 2. Open the file and peek at the JSON
				var file = FileAccess.open(full_path, FileAccess.READ)
				if file:
					var json_string = file.get_as_text()
					file.close()
					
					var level_data = JSON.parse_string(json_string)
					
					# 3. If it has our custom key, use that as the display name instead!
					if typeof(level_data) == TYPE_DICTIONARY and level_data.has("level_name"):
						display_name = level_data["level_name"]
						
				var index = level_list.add_item(display_name)
				level_list.set_item_metadata(index, full_path)
				
			file_name = dir.get_next()

func _on_level_list_item_selected(index: int) -> void:
	# 1. Grab the path from the item we clicked
	var selected_path = level_list.get_item_metadata(index)
	
	# 2. Store it in our Global script
	Global.level_to_load = selected_path
	
	# 3. Change to the new Details Hub instead of the Editor
	get_tree().call_deferred("change_scene_to_file", "res://scenes/rooms/level_details.tscn")

# New level button
func _on_create_new_button_pressed() -> void:
	# 1. Make sure the Levels folder exists
	if not DirAccess.dir_exists_absolute("user://Levels"):
		DirAccess.make_dir_absolute("user://Levels")
		
	# 2. Find a unique file name so we don't overwrite existing "untitled" levels
	var base_name = "untitled"
	var file_name = base_name + ".json"
	var file_path = "user://Levels/" + file_name
	var counter = 1
	
	# If "untitled.json" exists, try "untitled_1.json", "untitled_2.json", etc.
	while FileAccess.file_exists(file_path):
		file_name = base_name + "_" + str(counter) + ".json"
		file_path = "user://Levels/" + file_name
		counter += 1
		
	# 3. Create the default starting data for a brand new level
	var default_level_data: Dictionary = {
		"level_name": "Untitled", 
		"background": "res://Sprites/Backgrounds/background1.png", 
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

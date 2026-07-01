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
	
	# Open the directory and scan it
	var dir = DirAccess.open(LEVEL_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		# Loop through every file inside the folder
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				# Clean up the name for the UI (removes the ".json" extension for a cleaner look)
				var clean_name = file_name.replace(".json", "")
				var index = level_list.add_item(clean_name)
				
				# Save the full path in the metadata so we can load it later
				level_list.set_item_metadata(index, LEVEL_DIR + "/" + file_name)
				
			file_name = dir.get_next()

# Connect this to the 'item_selected' signal on your ItemList!
func _on_level_list_item_selected(index: int) -> void:
	# 1. Grab the path from the item we clicked
	var selected_path = level_list.get_item_metadata(index)
	
	# 2. Store it in global.gd
	Global.level_to_load = selected_path
	
	# 3. Load the Editor Scene (Make sure this path matches your exact editor scene name!)
	get_tree().change_scene_to_file("res://editor_root.tscn")

extends Control

@onready var name_edit: LineEdit = $NameEdit

# --- NEW: Reference to your counter label ---
@onready var count_label: Label = $ObjectCountLabel

func _ready() -> void:
	if FileAccess.file_exists(Global.level_to_load):
		name_edit.text = get_level_name_fast(Global.level_to_load)
		
		var total_objects = get_object_count_fast(Global.level_to_load)
		count_label.text = "Total Objects: " + str(total_objects)

# --- LIGHTNING FAST READING (End of File Seek) ---
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
		# name_parts[1] will be the actual level name!
		if name_parts.size() >= 2: 
			return name_parts[1]
			
	return "Unknown Level"

# Renaming logic (RegEx) 
func _on_name_edit_text_submitted(new_text: String) -> void:
	var file = FileAccess.open(Global.level_to_load, FileAccess.READ)
	if file:
		var raw_text = file.get_as_text()
		file.close()
		
		# Group 1 captures: "level_name": "
		# Group 2 captures: "
		var regex = RegEx.new()
		regex.compile('("level_name"\\s*:\\s*")[^"]+(")')
		
		# Fix: Use curly braces so numbers don't blend with the group ID
		var updated_text = regex.sub(raw_text, "${1}" + new_text + "${2}")
		
		var write_file = FileAccess.open(Global.level_to_load, FileAccess.WRITE)
		if write_file:
			write_file.store_string(updated_text)
			write_file.close()
			
	name_edit.release_focus()
	
func get_object_count_fast(target_path: String) -> int:
	var file = FileAccess.open(target_path, FileAccess.READ)
	if not file: return 0
	
	var raw_text = file.get_as_text()
	file.close()
	
	# Parse the JSON string to access the items dictionary key
	var level_data = JSON.parse_string(raw_text)
	if typeof(level_data) == TYPE_DICTIONARY and level_data.has("items"):
		var items_str = level_data["items"]
		if items_str.is_empty():
			return 0
		# Semicolons separate each item, so count them to get the total objects!
		return items_str.count(";") + 1
		
	return 0

# Button logic
func _on_edit_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/rooms/editor_root.tscn")

func _on_delete_button_pressed() -> void:
	if FileAccess.file_exists(Global.level_to_load):
		DirAccess.remove_absolute(Global.level_to_load)
	_on_back_button_pressed()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/rooms/level_browser.tscn")
	Global.level_to_load = ""

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/rooms/play_scene.tscn")

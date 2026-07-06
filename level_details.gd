extends Control

@onready var name_edit: LineEdit = $NameEdit

# We store the full parsed dictionary so we can save it back easily without losing the items
var current_level_data: Dictionary = {}

func _ready() -> void:
	# 1. Open the JSON file passed from the Level Browser
	if FileAccess.file_exists(Global.level_to_load):
		var file = FileAccess.open(Global.level_to_load, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		# 2. Parse it and extract the name
		var parsed = JSON.parse_string(json_string)
		if typeof(parsed) == TYPE_DICTIONARY:
			current_level_data = parsed
			if current_level_data.has("level_name"):
				name_edit.text = current_level_data["level_name"]

# --- RENAMING LOGIC ---
func _on_name_edit_text_submitted(new_text: String) -> void:
	# Update the dictionary with the newly typed name
	current_level_data["level_name"] = new_text
	
	# Save the updated dictionary back to the exact same JSON file
	var file = FileAccess.open(Global.level_to_load, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(current_level_data, "\t")
		file.store_string(json_string)
		file.close()
		
	# Deselect the text box so they stop typing
	name_edit.release_focus()

# --- BUTTON LOGIC ---
func _on_edit_button_pressed() -> void:
	# The Global.level_to_load is still intact, so the EditorRoot will catch it!
	get_tree().change_scene_to_file("res://scenes/rooms/editor_root.tscn")

func _on_delete_button_pressed() -> void:
	# Delete the JSON file from the hard drive
	if FileAccess.file_exists(Global.level_to_load):
		DirAccess.remove_absolute(Global.level_to_load)
		
	# Return to the browser
	_on_back_button_pressed()

func _on_back_button_pressed() -> void:
	# Just go back without deleting
	get_tree().change_scene_to_file("res://scenes/rooms/level_browser.tscn")
	# Change level to load to None
	Global.level_to_load = ""

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/rooms/play_scene.tscn")
	

extends Node2D

@onready var level_canvas: Node2D = $LevelCanvas
@onready var player: CharacterBody2D = $Player

# For the background texture
@onready var bg_rect: TextureRect = $BackgroundCanvas/BackgroundLayer/Background

@onready var pause_menu: ColorRect = $GameOverlay/PauseMenu

@onready var level_name_label: Label = $GameOverlay/PauseMenu/LevelNameLabel

var level_name = ""

var paused = false

var respawn_time = 1

func _ready() -> void:
	
	# Hides menu
	if pause_menu:
		pause_menu.visible = false
	
	# 1. Grab the level path from your Global script
	if Global.level_to_load != "":
		load_level(Global.level_to_load)
	
	# 2. (Optional) Set the player's starting position based on level data if you add spawn points later!

# Loading level function
func load_level(target_path: String) -> void:
	if not FileAccess.file_exists(target_path):
		print("No save file found at: ", target_path)
		return

	for child in level_canvas.get_children():
		child.queue_free()
		
	var file = FileAccess.open(target_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var level_data = JSON.parse_string(json_string)
		
		# Check if the data is the Dictionary format
		if typeof(level_data) == TYPE_DICTIONARY and level_data.has("items"):
			
			# Load and apply the background
			if level_data.has("background"):
				var current_bg_path = level_data["background"]
				var loaded_texture = load(current_bg_path)
				if loaded_texture:
					bg_rect.texture = loaded_texture
					
			if level_data.has("level_name"):
				level_name = level_data["level_name"]
				level_name_label.text = level_name
			
			# Loop through the items array inside library and loads them using their properties
			for item in level_data["items"]:
				var resource = load(item["scene_path"])
				if resource:
					var new_object = resource.instantiate()
					# Position of object
					new_object.global_position = Vector2(item["x"], item["y"])
					
					# Apply rotation (defaults to 0.0)
					new_object.rotation_degrees = item.get("rotation", 0.0)
					
					# Apply scale (defaults to 1.0)
					var s_x = item.get("scale_x", 1.0)
					var s_y = item.get("scale_y", 1.0)
					new_object.scale = Vector2(s_x, s_y)
					
					# Apply the saved ID, or create a new one if it's missing
					var loaded_id = item.get("id", str(Time.get_ticks_usec()))
					new_object.set_meta("unique_id", loaded_id)
					
					level_canvas.add_child(new_object)
					

func _on_player_player_died() -> void:
	
	# Waits so doesn't respawn immediately
	await get_tree().create_timer(respawn_time, false).timeout
	
	# Reload scene and respawn
	get_tree().reload_current_scene()
	
func _on_resume_button_pressed() -> void:
	# Hide the menu to resume game
	if pause_menu:
		pause_menu.visible = false
	paused = false	
	
	get_tree().paused = false
	
# Pause Menu logic
func _on_pause_button_pressed() -> void:
	# Shows name of level
	if level_name_label:
		level_name_label.text = level_name
		
	# Reveal the menu
	if pause_menu:
		pause_menu.visible = true
	paused = true
	
	# Pauses the game
	# GameOverlay node set process mode set to "Always" so it always runs
	get_tree().paused = true
	
func _on_quit_button_pressed() -> void:
	# Return to Level Browser scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/rooms/level_details.tscn")

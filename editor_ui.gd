extends CanvasLayer

# Edit action pressed
signal edit_action_requested(action_name: String)

# The build tab items
@onready var obstacles_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Obstacles
@onready var deco_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Decoration

# The edit tab items
@onready var actions_list: ItemList = $EditorPanel/MainTabContainer/Edit/Actions

# Level Settings song
@onready var http_request: HTTPRequest = $LevelSettingsMenu/HTTPRequest
@onready var metadata_request: HTTPRequest = $LevelSettingsMenu/MetadataRequest
@onready var song_id_input: LineEdit = $LevelSettingsMenu/SongIDInput
@onready var status_label: Label = $LevelSettingsMenu/StatusLabel
@onready var play_music_btn: Button = $LevelSettingsMenu/PlayButton

# References for your display container
@onready var song_name_label: Label = $LevelSettingsMenu/SongInfoContainer/SongNameLabel
@onready var artist_label: Label = $LevelSettingsMenu/SongInfoContainer/ArtistLabel
@onready var song_id_display: Label = $LevelSettingsMenu/SongInfoContainer/SongIDLabel

var current_selected_objects: Array = []

# For level settings menu
# Tracks the colors for Background (0), Middleground (1), and Foreground (2)
var ground_colors: Dictionary = {
	0: Color(1, 1, 1, 1), 
	1: Color(1, 1, 1, 1), 
	2: Color(1, 1, 1, 1)  
}

# Dictionary to remember what was visible before playtesting
var pre_test_visibility: Dictionary = {}

@onready var settings_color_picker: ColorPickerButton = $LevelSettingsMenu/ColorPickerButton 
@onready var grounds_container: TabContainer = $LevelSettingsMenu/GroundsContainer

# 1. ADD @onready HERE so Godot allows function calls inside the dictionary
@onready var item_database: Dictionary = {
	"obstacles": [
		{
			"name": "Black Hole",
			"icon": preload("res://Resources/Icons/black_hole.svg"),
			"scene_path": "res://scenes/objects/black_hole.tscn"
		},
		{
			"name": "Meteor",
			"icon": preload("res://Resources/Icons/meteor.svg"),
			"scene_path": "res://scenes/objects/meteor.tscn"
		},
		{
			"name": "Block",
			"icon": preload("res://Resources/Icons/block1.svg"), 
			"scene_path": "res://scenes/objects/block.tscn"
		}
	],
	"deco": [
		{
			"name": "Star",
			"icon": get_sheet_icon(Rect2(0, 0, 64, 64)), 
			"scene_path": "res://scenes/objects/deco/star.tscn"
		},
		{
			"name": "Side Line",
			"icon": get_sheet_icon(Rect2(65, 0, 64, 64)), 
			"scene_path": "res://scenes/objects/deco/side_line.tscn"
		},
		{
			"name": "Middle Line",
			"icon": get_sheet_icon(Rect2(130, 0, 64, 64)), 
			"scene_path": "res://scenes/objects/deco/middle_line.tscn"
		},
		{
			"name": "Square",
			"icon": get_sheet_icon(Rect2(195, 0, 64, 64)), 
			"scene_path": "res://scenes/objects/deco/square.tscn"
		},
		{
			"name": "Half Square",
			"icon": get_sheet_icon(Rect2(260, 0, 64, 64)), 
			"scene_path": "res://scenes/objects/deco/half_square.tscn"
		},
	]
}

# Define edit buttons
var edit_actions: Array = [
	{"icon": preload("res://Resources/Icons/move_up.svg"), "action": "move_up_tiny"},
	{"icon": preload("res://Resources/Icons/move_down.svg"), "action": "move_down_tiny"},
	{"icon": preload("res://Resources/Icons/move_left.svg"), "action": "move_left_tiny"},
	{"icon": preload("res://Resources/Icons/move_right.svg"), "action": "move_right_tiny"},
	{"icon": preload("res://Resources/icon.svg"), "action": "rotate_left"},
	{"icon": preload("res://Resources/icon.svg"), "action": "rotate_right"},
	{"icon": preload("res://Resources/icon.svg"), "action": "show_hide_gizmo"}
]

# Stores the path so the main script can grab it when you click the canvas.
var selected_scene_path: String = ""

# Takes the region provided in parameter and creates a sliced texture from your deco sheet
func get_sheet_icon(region: Rect2) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = preload("res://Resources/Objects/decosheet.png")
	atlas.region = region
	return atlas
	
func _ready() -> void:
	populate_object_list(obstacles_list, item_database["obstacles"])
	populate_object_list(deco_list, item_database["deco"])
	populate_actions_tab()
	
	# Connect the Build tab's inner container like Obstacle, Deco, etc.
	var objects_container = $EditorPanel/MainTabContainer/Build/ObjectsContainer
	if objects_container is TabContainer:
		objects_container.tab_changed.connect(_on_objects_container_tab_changed)
	settings_color_picker.color_changed.connect(_on_settings_color_changed)
	grounds_container.tab_changed.connect(_on_grounds_tab_changed)
		
	load_images_from_folder($LevelSettingsMenu/GroundsContainer/Background, "res://Resources/Backgrounds")

func _on_exit_button_pressed() -> void:
	$ColorChannelMenu.visible = false
	$LevelSettingsMenu.visible = false
	get_parent().paused = false

func update_selected_target(target_node):
	current_selected_objects = target_node
	
func load_images_from_folder(target_list: ItemList, folder_path: String) -> void:
	target_list.clear()
	
	# Open the directory
	var dir = DirAccess.open(folder_path)
	if dir:
		# Loop through all files found in that folder
		for file_name in dir.get_files():
			# Filter out .import files, we only want the direct image files
			if file_name.ends_with(".png") or file_name.ends_with(".jpg"):
				var full_path = folder_path + "/" + file_name
				var texture = load(full_path)
				
				# Add to the ItemList like in build menu
				var index = target_list.add_item("", texture)
				target_list.set_item_metadata(index, full_path)
	else:
		print("Warning: Could not open folder at ", folder_path)

# EDITOR PANEL FUNCTIONS
func populate_object_list(target_list: ItemList, item_array: Array) -> void:
	target_list.clear()
	
	for item in item_array:
		var index = target_list.add_item("", item["icon"])
		target_list.set_item_metadata(index, item["scene_path"])
		
func populate_actions_tab() -> void:
	actions_list.clear()
	for item in edit_actions:
		# Using "" to hide the text like in objects tab
		var index = actions_list.add_item("", item["icon"]) 
		actions_list.set_item_metadata(index, item["action"])

func _on_objects_container_tab_changed(tab: int) -> void:
	# Clear the path so the editor doesn't accidentally build an item from the hidden tab
	selected_scene_path = ""

	if tab == 0: # Obstacles
		var selected = obstacles_list.get_selected_items()
		if selected.size() > 0:
			_on_object_item_selected(selected[0])		
	elif tab == 1: # Decoration
		var selected = deco_list.get_selected_items()
		if selected.size() > 0:
			_on_decoration_item_selected(selected[0])

func _on_object_item_selected(index: int) -> void:
	# Update the variable so the placement script knows what to build
	selected_scene_path = obstacles_list.get_item_metadata(index)
	print("Ready to place object from path: ", selected_scene_path)	
	
func _on_decoration_item_selected(index: int) -> void:
	selected_scene_path = deco_list.get_item_metadata(index)
	print("Ready to place object from path: ", selected_scene_path)

func _on_actions_item_selected(index: int) -> void:
	var action_name = actions_list.get_item_metadata(index)
	
	# Shout out to the main script that a button was pressed
	edit_action_requested.emit(action_name)
	
	# Instantly deselect the item so it acts like a clickable button instead of a toggle
	actions_list.deselect_all()
	
func _on_edit_object_button_pressed() -> void:
	$ColorChannelMenu.visible = true 
	get_parent().paused  = true
	
	if current_selected_objects:
		for obj in current_selected_objects:
			if obj.has_meta("color_channel"):
				# 2. Grab the channel integer
				var channel = obj.get_meta("color_channel")
				
				# 3. Construct the name of the button you want to press
				var button_name = "Channel" + str(channel) + "Button"
				
				# 4. Grab the button node and force it down
				var target_button = $ColorChannelMenu.get_node(button_name)
				if target_button:
					target_button.button_pressed = true
					
					# 1. Update the physical color box
					$ColorChannelMenu/ColorPickerButton.color = Global.get_channel_color(channel)
					
					# 2. Tell the main editor script that the active channel has changed.
					# Since editor_ui is a child of the root, we use get_parent() to reach the variable.
					get_parent().current_editing_channel = channel

# LEVEL SETTING FUNCTIONS
func _on_background_item_selected(index: int) -> void:
	# 1. Grab the specific ItemList node and ask it for the metadata at the clicked index
	var selected_path = $LevelSettingsMenu/GroundsContainer/Background.get_item_metadata(index)
	
	# 2. Send that retrieved string up to editor_root.gd
	get_parent().change_background(selected_path)
	
func _on_level_settings_button_pressed() -> void:
	$LevelSettingsMenu.visible = true
	get_parent().paused = true
	
func _on_grounds_tab_changed(tab: int) -> void:
	# 1. Ask the dictionary what color was saved for this specific tab
	# 2. Force the UI button to display that color
	settings_color_picker.color = ground_colors[tab]

func _on_settings_color_changed(new_color: Color) -> void:
	var current_tab = grounds_container.current_tab
	
	# 1. Save the new color into our dictionary so it doesn't leak into other tabs
	ground_colors[current_tab] = new_color
	
	# Actually updates the ground color in editor root
	get_parent().update_ground_color(current_tab, new_color)
	
# Test Button
func _on_test_button_pressed() -> void:
	# Calls the logic on editor_root.gd
	get_parent().toggle_playtest()

func toggle_playtest_ui(is_testing: bool) -> void:
	if is_testing:
		pre_test_visibility.clear()
		# Loop through all direct UI elements
		for child in get_children():
			# Ignore the test button so it stays on screen
			# NOTE: Change "TestButton" if your node is named slightly differently!
			if child.name != "TestButton":
				# Save its current state, then hide it
				pre_test_visibility[child] = child.visible
				child.visible = false
	else:
		# Restore all UI elements to their exact previous state
		for child in pre_test_visibility.keys():
			if is_instance_valid(child):
				child.visible = pre_test_visibility[child]
				
func _on_download_button_pressed() -> void:
	var song_id = song_id_input.text.strip_edges()
	
	if song_id != "":
		status_label.text = "Fetching data..."
		
		# 1. Request the HTML webpage first
		var page_url = "https://www.newgrounds.com/audio/listen/" + song_id
		metadata_request.request(page_url)
		
func _on_http_request_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# 200 means the server said "OK"
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var song_id = song_id_input.text.strip_edges()
		
		# Define where to save it
		var save_directory = "user://songs/"
		var file_path = save_directory + song_id + ".mp3"
		
		# Make sure the folder actually exists before we try to save inside it
		if not DirAccess.dir_exists_absolute(save_directory):
			DirAccess.make_dir_absolute(save_directory)
			
		# Write the raw bytes to the file
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_buffer(body)
			file.close()
			status_label.text = "Saved to: " + file_path
			
		get_parent().save_manager.current_song_id = song_id
		# 2. orce the level to save to disk immediately 
		get_parent().save_manager._on_save_button_pressed()
		# 3. Load the raw audio into the editor so your Play button works right now
		get_parent().save_manager.load_song_to_editor(song_id)
		
	else:
		status_label.text = "Download failed! Code: " + str(response_code)

func _on_metadata_request_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var html_string = body.get_string_from_utf8()
		
		var parsed_title = "Unknown"
		var parsed_author = "Unknown"
		
		# 1. Parse Title and Artist the old way (from the JS string)
		if "'title':" in html_string:
			parsed_title = html_string.get_slice("'title': \"", 1).get_slice("\"", 0)
			
		if "'author':" in html_string:
			parsed_author = html_string.get_slice("'author': \"", 1).get_slice("\"", 0)
			
		# Update the UI
		song_name_label.text = "Song: " + parsed_title
		artist_label.text = "Artist: " + parsed_author
		song_id_display.text = "ID: " + song_id_input.text.strip_edges()
		
		# Send to Save Manager
		get_parent().save_manager.current_song_name = parsed_title
		get_parent().save_manager.current_song_artist = parsed_author
		
		# 2. Parse the direct MP3 link from the og:audio tag
		if "property=\"og:audio\" content=\"" in html_string:
			var mp3_url = html_string.get_slice("property=\"og:audio\" content=\"", 1).get_slice("\"", 0)
			
			status_label.text = "Downloading audio..."
			
			# 3. Fire the SECOND request to download the actual MP3
			http_request.request(mp3_url)
		else:
			status_label.text = "Audio link not found!"
	else:
		status_label.text = "Failed to load page data!"

func update_song_ui(title: String, artist: String, id: String) -> void:
	song_name_label.text = "Song: " + title
	artist_label.text = "Artist: " + artist
	song_id_display.text = "ID: " + id

func _on_play_button_pressed() -> void:
	# Reach up to the root to grab the music player
	var music_player = get_parent().get_node_or_null("LevelMusic")
	
	if music_player and music_player.stream != null:
		if music_player.playing:
			music_player.stop()
			play_music_btn.text = "Play"
		else:
			music_player.play()
			play_music_btn.text = "Stop"

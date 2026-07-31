extends CanvasLayer

# Edit action pressed
signal edit_action_requested(action_name: String)

# The build tab items
@onready var obstacles_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Obstacles
@onready var deco_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Decoration

# The edit tab items
@onready var actions_list: ItemList = $EditorPanel/MainTabContainer/Edit/Actions

# NCS UI REFERENCES
@onready var ncs_song_id_input: LineEdit = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/SongIDInput
@onready var ncs_status_label: Label = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/StatusLabel

@onready var song_option_container: Control = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/SongOptionContainer
@onready var regular_btn: Button = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/SongOptionContainer/RegularButton
@onready var instrumental_btn: Button = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/SongOptionContainer/InstrumentalButton

# NEWGROUNDS UI REFERENCES
@onready var ng_song_id_input: LineEdit = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/Newgrounds/NG_SongIDInput
@onready var ng_status_label: Label = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/Newgrounds/NG_StatusLabel

# GROUP ID UI REFERENCES
@onready var edit_group_node: Node = $EditGroupNode
@onready var edit_group_menu: Control = $EditGroupNode/EditGroupMenu
@onready var group_id_input: LineEdit = $EditGroupNode/EditGroupMenu/GroupIDInput
@onready var add_group_btn: Button = $EditGroupNode/EditGroupMenu/AddGroupIDButton
@onready var active_groups_container: Container = $EditGroupNode/EditGroupMenu/ActiveGroupsContainer
@onready var edit_group_btn: Button = $SelectionMenu/EditGroupButton

# Unified Play Button
@onready var play_music_btn: Button = $LevelSettingsNode/LevelSettingsMenu/PlayButton

# Unified Song Info UI references
@onready var song_name_label: Label = $LevelSettingsNode/LevelSettingsMenu/SongInfoContainer/SongNameLabel
@onready var artist_label: Label = $LevelSettingsNode/LevelSettingsMenu/SongInfoContainer/ArtistLabel
@onready var song_id_display: Label = $LevelSettingsNode/LevelSettingsMenu/SongInfoContainer/SongIDLabel

@onready var music_downloader: Node = $LevelSettingsNode/LevelSettingsMenu/MusicDownloader

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

@onready var settings_color_picker: ColorPickerButton = $LevelSettingsNode/LevelSettingsMenu/ColorPickerButton 
@onready var grounds_container: TabContainer = $LevelSettingsNode/LevelSettingsMenu/GroundsContainer

@onready var item_database: Dictionary = {
	"obstacles": [
		{
			"name": "Block",
			"icon": get_game_sheet_icon(Rect2(0, 0, 64, 64)),
			"scene_path": "res://scenes/objects/block.tscn"
		},
		{
			"name": "Spike",
			"icon": get_game_sheet_icon(Rect2(0, 130, 64, 64)),
			"scene_path": "res://scenes/objects/spike.tscn"
		},
		{
			"name": "Clear Block",
			"icon": get_game_sheet_icon(Rect2(65, 130, 64, 64)),
			"scene_path": "res://scenes/objects/clear_block.tscn"
		},
		{
			"name": "Clear Spike",
			"icon": get_game_sheet_icon(Rect2(0, 65, 64, 64)),
			"scene_path": "res://scenes/objects/clear_spike.tscn"
		},
		{
			"name": "Sawblade1",
			"icon": get_game_sheet_icon(Rect2(190, 0, 128, 128)),
			"scene_path": "res://scenes/objects/sawblade1.tscn"
		},
		{
			"name": "Meteor",
			"icon": get_game_sheet_icon(Rect2(65, 0, 113, 128)),
			"scene_path": "res://scenes/objects/meteor.tscn"
		},
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

var edit_actions: Array = [
	{"icon": preload("res://Resources/Icons/move_up_small.svg"), "action": "move_up_small"},
	{"icon": preload("res://Resources/Icons/move_down_small.svg"), "action": "move_down_small"},
	{"icon": preload("res://Resources/Icons/move_left_small.svg"), "action": "move_left_small"},
	{"icon": preload("res://Resources/Icons/move_right_small.svg"), "action": "move_right_small"},
	{"icon": preload("res://Resources/Icons/move_up_medium.png"), "action": "move_up_medium"},
	{"icon": preload("res://Resources/Icons/move_down_medium.png"), "action": "move_down_medium"},
	{"icon": preload("res://Resources/Icons/move_left_medium.png"), "action": "move_left_medium"},
	{"icon": preload("res://Resources/Icons/move_right_medium.png"), "action": "move_right_medium"},
	{"icon": preload("res://Resources/Icons/rotate_left_30.png"), "action": "rotate_left"},
	{"icon": preload("res://Resources/Icons/rotate_right_30.png"), "action": "rotate_right"},
	{"icon": preload("res://Resources/icon.svg"), "action": "show_hide_gizmo"}
]

var selected_scene_path: String = ""

func get_sheet_icon(region: Rect2) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = preload("res://Resources/Objects/decosheet.png")
	atlas.region = region
	return atlas
	
func get_game_sheet_icon(region: Rect2) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = preload("res://Resources/Objects/gamesheet.png") 
	atlas.region = region
	return atlas
	
func _ready() -> void:
	populate_object_list(obstacles_list, item_database["obstacles"])
	populate_object_list(deco_list, item_database["deco"])
	populate_actions_tab()
	
	# Hide regular and instrumental buttons
	song_option_container.hide()
	
	# Connect music downloader signals
	music_downloader.status_updated.connect(_on_status_updated)
	music_downloader.download_complete.connect(_on_download_complete)
	music_downloader.ncs_options_available.connect(_on_ncs_options_available)
	
	var objects_container = $EditorPanel/MainTabContainer/Build/ObjectsContainer
	if objects_container is TabContainer:
		objects_container.tab_changed.connect(_on_objects_container_tab_changed)
	settings_color_picker.color_changed.connect(_on_settings_color_changed)
	grounds_container.tab_changed.connect(_on_grounds_tab_changed)
		
	load_images_from_folder($LevelSettingsNode/LevelSettingsMenu/GroundsContainer/Background, "res://Resources/Backgrounds")

func _on_exit_button_pressed() -> void:
	$ColorChannelNode.visible = false
	$LevelSettingsNode.visible = false
	$EditGroupNode.visible = false
	get_parent().paused = false
	
	var music_player = get_parent().get_node_or_null("LevelMusic")
	if music_player and music_player.stream != null:
		if music_player.playing:
			music_player.stop()
			play_music_btn.text = "Play"

func update_selected_target(target_node):
	current_selected_objects = target_node
	
func load_images_from_folder(target_list: ItemList, folder_path: String) -> void:
	target_list.clear()
	var dir = DirAccess.open(folder_path)
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".png") or file_name.ends_with(".jpg"):
				var full_path = folder_path + "/" + file_name
				var texture = load(full_path)
				var index = target_list.add_item("", texture)
				target_list.set_item_metadata(index, full_path)
	else:
		print("Warning: Could not open folder at ", folder_path)

func populate_object_list(target_list: ItemList, item_array: Array) -> void:
	target_list.clear()
	for item in item_array:
		var index = target_list.add_item("", item["icon"])
		target_list.set_item_metadata(index, item["scene_path"])
		
func populate_actions_tab() -> void:
	actions_list.clear()
	for item in edit_actions:
		var index = actions_list.add_item("", item["icon"]) 
		actions_list.set_item_metadata(index, item["action"])

func _on_objects_container_tab_changed(tab: int) -> void:
	selected_scene_path = ""
	if tab == 0: 
		var selected = obstacles_list.get_selected_items()
		if selected.size() > 0:
			_on_object_item_selected(selected[0])		
	elif tab == 1: 
		var selected = deco_list.get_selected_items()
		if selected.size() > 0:
			_on_decoration_item_selected(selected[0])

func _on_object_item_selected(index: int) -> void:
	selected_scene_path = obstacles_list.get_item_metadata(index)
	
func _on_decoration_item_selected(index: int) -> void:
	selected_scene_path = deco_list.get_item_metadata(index)

func _on_actions_item_selected(index: int) -> void:
	var action_name = actions_list.get_item_metadata(index)
	edit_action_requested.emit(action_name)
	actions_list.deselect_all()
	
func _on_edit_object_button_pressed() -> void:
	$ColorChannelNode.visible = true 
	get_parent().paused  = true
	if current_selected_objects:
		for obj in current_selected_objects:
			if obj.has_meta("color_channel"):
				var channel = obj.get_meta("color_channel")
				var button_name = "Channel" + str(channel) + "Button"
				var target_button = $ColorChannelNode/ColorChannelMenu.get_node(button_name)
				if target_button:
					target_button.button_pressed = true
					$ColorChannelNode/ColorChannelMenu/ColorPickerButton.color = Global.get_channel_color(channel)
					get_parent().current_editing_channel = channel

func _on_background_item_selected(index: int) -> void:
	var selected_path = $LevelSettingsNode/LevelSettingsMenu/GroundsContainer/Background.get_item_metadata(index)
	get_parent().change_background(selected_path)
	
func _on_level_settings_button_pressed() -> void:
	$LevelSettingsNode.visible = true
	get_parent().paused = true
	
func _on_grounds_tab_changed(tab: int) -> void:
	settings_color_picker.color = ground_colors[tab]

func _on_settings_color_changed(new_color: Color) -> void:
	var current_tab = grounds_container.current_tab
	ground_colors[current_tab] = new_color
	get_parent().update_ground_color(current_tab, new_color)
	
func _on_test_button_pressed() -> void:
	get_parent().toggle_playtest()

func toggle_playtest_ui(is_testing: bool) -> void:
	if is_testing:
		pre_test_visibility.clear()
		for child in get_children():
			if child.name != "TestButton":
				pre_test_visibility[child] = child.visible
				child.visible = false
	else:
		for child in pre_test_visibility.keys():
			if is_instance_valid(child):
				child.visible = pre_test_visibility[child]

# NCS LOGIC
func _on_regular_button_pressed() -> void:
	music_downloader.download_ncs_regular()

func _on_instrumental_button_pressed() -> void:
	music_downloader.download_ncs_instrumental()

				
func _on_get_button_pressed() -> void:
	var song_id = ncs_song_id_input.text.strip_edges()
	if song_id != "":
		music_downloader.fetch_ncs(song_id)

# NEWGROUNDS LOGIC
func _on_ng_get_button_pressed() -> void:
	var song_id = ng_song_id_input.text.strip_edges()
	if song_id != "":
		music_downloader.fetch_newgrounds(song_id)

func _on_status_updated(message: String, is_ncs: bool) -> void:
	if is_ncs:
		ncs_status_label.text = message
	else:
		ng_status_label.text = message

func _on_ncs_options_available(regular_url: String, inst_url: String) -> void:
	song_option_container.show()
	regular_btn.disabled = (regular_url == "")
	# Only show the button if there is a valid link
	instrumental_btn.visible = (inst_url != "")

func _on_download_complete(title: String, artist: String, song_id: String, audio_data: PackedByteArray) -> void:
	update_song_ui(title, artist, song_id)
	
	# Send the data to the save manager to store locally
	get_parent().save_manager.save_downloaded_song(song_id, title, artist, audio_data)
	
	# Convert the raw bytes into a playable MP3
	var new_audio = AudioStreamMP3.new()
	new_audio.data = audio_data
	
	# Assign it to music player node
	var music_player = get_parent().get_node_or_null("LevelMusic")
	if music_player:
		music_player.stream = new_audio

func update_song_ui(title: String, artist: String, id: String) -> void:
	song_name_label.text = "Song: " + title
	artist_label.text = "Artist: " + artist
	song_id_display.text = "ID: " + id
	
	# Update the unified play button
	play_music_btn.text = "Play"

func _on_play_button_pressed() -> void:
	_toggle_playback(play_music_btn)

func _toggle_playback(btn_node: Button) -> void:
	var music_player = get_parent().get_node_or_null("LevelMusic")
	if music_player and music_player.stream != null:
		if music_player.playing:
			music_player.stop()
			btn_node.text = "Play"
		else:
			music_player.play()
			btn_node.text = "Stop"
			
func _on_edit_group_button_pressed() -> void:
	edit_group_node.visible = true
	get_parent().paused = true
	refresh_group_ui()

func refresh_group_ui() -> void:
	# Clear out the old buttons
	for child in active_groups_container.get_children():
		child.queue_free()
		
	if current_selected_objects.is_empty():
		return
		
	# Find all unique groups across everything currently selected
	var unique_groups = {}
	for obj in current_selected_objects:
		if obj.has_meta("groups"):
			for g_id in obj.get_meta("groups"):
				unique_groups[g_id] = true
				
	# Generate a removal button for each group found
	for g_id in unique_groups.keys():
		var btn = Button.new()
		btn.text = str(g_id)
		
		# Use a lambda function to pass the specific ID to the removal function
		btn.pressed.connect(func(): _remove_group_from_selection(g_id))
		active_groups_container.add_child(btn)

func _on_add_group_id_button_pressed() -> void:
	var input_text = group_id_input.text.strip_edges()
	
	# Stop if they typed letters instead of numbers
	if not input_text.is_valid_int():
		return 
		
	var new_group = input_text.to_int()
	
	for obj in current_selected_objects:
		var groups = []
		if obj.has_meta("groups"):
			# Always duplicate arrays when getting them from meta to avoid shared reference bugs
			groups = obj.get_meta("groups").duplicate() 
			
		if not groups.has(new_group):
			groups.append(new_group)
			
		obj.set_meta("groups", groups)
		
	group_id_input.text = "" 
	refresh_group_ui()

func _remove_group_from_selection(group_id: int) -> void:
	for obj in current_selected_objects:
		if obj.has_meta("groups"):
			var groups = obj.get_meta("groups").duplicate()
			if groups.has(group_id):
				groups.erase(group_id)
				obj.set_meta("groups", groups)
				
	# Rebuild the UI now that the group is gone
	refresh_group_ui()

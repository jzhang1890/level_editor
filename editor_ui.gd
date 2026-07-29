extends CanvasLayer

# Edit action pressed
signal edit_action_requested(action_name: String)

# The build tab items
@onready var obstacles_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Obstacles
@onready var deco_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Decoration

# The edit tab items
@onready var actions_list: ItemList = $EditorPanel/MainTabContainer/Edit/Actions

# Tracks if we are scraping the HTML or downloading the MP3
var is_fetching_html: bool = false
var is_primary_download: bool = false
var fallback_mp3_url: String = ""
var fallback_title: String = ""
var fallback_artist: String = ""
var regular_download_url: String = ""
var instrumental_download_url: String = ""
var is_instrumental_download: bool = false

# NCS UI REFERENCES
@onready var ncs_http_request: HTTPRequest = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/HTTPRequest
@onready var ncs_song_id_input: LineEdit = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/SongIDInput
@onready var ncs_status_label: Label = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/StatusLabel

@onready var song_option_container: Control = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/SongOptionContainer
@onready var regular_btn: Button = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/SongOptionContainer/RegularButton
@onready var instrumental_btn: Button = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/NCS/SongOptionContainer/InstrumentalButton

# NEWGROUNDS UI REFERENCES
@onready var ng_http_request: HTTPRequest = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/Newgrounds/NG_HTTPRequest
@onready var ng_song_id_input: LineEdit = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/Newgrounds/NG_SongIDInput
@onready var ng_status_label: Label = $LevelSettingsNode/LevelSettingsMenu/MusicSourceTabs/Newgrounds/NG_StatusLabel

# Unified Play Button
@onready var play_music_btn: Button = $LevelSettingsNode/LevelSettingsMenu/PlayButton

# Unified Song Info UI references
@onready var song_name_label: Label = $LevelSettingsNode/LevelSettingsMenu/SongInfoContainer/SongNameLabel
@onready var artist_label: Label = $LevelSettingsNode/LevelSettingsMenu/SongInfoContainer/ArtistLabel
@onready var song_id_display: Label = $LevelSettingsNode/LevelSettingsMenu/SongInfoContainer/SongIDLabel

var is_ng_fetching_html: bool = false
var ng_mp3_url: String = ""
var ng_title: String = ""
var ng_artist: String = ""


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

var edit_actions: Array = [
	{"icon": preload("res://Resources/Icons/move_up.svg"), "action": "move_up_tiny"},
	{"icon": preload("res://Resources/Icons/move_down.svg"), "action": "move_down_tiny"},
	{"icon": preload("res://Resources/Icons/move_left.svg"), "action": "move_left_tiny"},
	{"icon": preload("res://Resources/Icons/move_right.svg"), "action": "move_right_tiny"},
	{"icon": preload("res://Resources/icon.svg"), "action": "rotate_left"},
	{"icon": preload("res://Resources/icon.svg"), "action": "rotate_right"},
	{"icon": preload("res://Resources/icon.svg"), "action": "show_hide_gizmo"}
]

var selected_scene_path: String = ""

func get_sheet_icon(region: Rect2) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = preload("res://Resources/Objects/decosheet.png")
	atlas.region = region
	return atlas
	
func _ready() -> void:
	populate_object_list(obstacles_list, item_database["obstacles"])
	populate_object_list(deco_list, item_database["deco"])
	populate_actions_tab()
	
	# Connect NCS UI option buttons
	regular_btn.pressed.connect(_on_regular_button_pressed)
	instrumental_btn.pressed.connect(_on_instrumental_button_pressed)
	song_option_container.hide()
	
	var objects_container = $EditorPanel/MainTabContainer/Build/ObjectsContainer
	if objects_container is TabContainer:
		objects_container.tab_changed.connect(_on_objects_container_tab_changed)
	settings_color_picker.color_changed.connect(_on_settings_color_changed)
	grounds_container.tab_changed.connect(_on_grounds_tab_changed)
		
	load_images_from_folder($LevelSettingsNode/LevelSettingsMenu/GroundsContainer/Background, "res://Resources/Backgrounds")

func _on_exit_button_pressed() -> void:
	$ColorChannelNode.visible = false
	$LevelSettingsNode.visible = false
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
	if regular_download_url == "":
		return
	ncs_status_label.text = "Downloading MP3..."
	is_fetching_html = false
	is_primary_download = true
	is_instrumental_download = false
	
	get_parent().save_manager.current_song_name = fallback_title
	get_parent().save_manager.current_song_artist = fallback_artist
	
	ncs_http_request.timeout = 10.0
	ncs_http_request.request(regular_download_url)

func _on_instrumental_button_pressed() -> void:
	if instrumental_download_url == "":
		return
	ncs_status_label.text = "Downloading Instrumental MP3..."
	is_fetching_html = false
	is_primary_download = false
	is_instrumental_download = true
	
	get_parent().save_manager.current_song_name = fallback_title + " (Instrumental)"
	get_parent().save_manager.current_song_artist = fallback_artist
	
	ncs_http_request.timeout = 0
	ncs_http_request.request(instrumental_download_url)
				
func _on_get_button_pressed() -> void:
	var song_id = ncs_song_id_input.text.strip_edges()
	if song_id != "":
		ncs_status_label.text = "Fetching NCS link..."
		is_fetching_html = true 
		var url = "https://ncs.io/" + song_id
		ncs_http_request.request(url)

func _on_ncs_http_request_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_fetching_html:
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var html_string = body.get_string_from_utf8()
			
			if "<title>" in html_string:
				var raw_title = html_string.get_slice("<title>", 1).get_slice("</title>", 0).xml_unescape().replace(" on NCS", "")
				var title_parts = raw_title.split(" by ")
				if title_parts.size() >= 2:
					fallback_title = title_parts[0].strip_edges()
					fallback_artist = title_parts[1].strip_edges()
			if "id=\"player\" data-url=\"" in html_string:
				fallback_mp3_url = html_string.get_slice("id=\"player\" data-url=\"", 1).get_slice("\"", 0)

			var href_chunks = html_string.split("href=\"/track/download/")
			for i in range(1, href_chunks.size()):
				var chunk = href_chunks[i]
				var href_path = chunk.get_slice("\"", 0).replace(" ", "%20")
				var full_link = "https://ncs.io/track/download/" + href_path
				
				if "data-version=\"Instrumental\"" in chunk or "/i%20" in href_path or "/i " in chunk:
					instrumental_download_url = full_link
				elif "data-version=\"Regular\"" in chunk or regular_download_url == "":
					regular_download_url = full_link

			if regular_download_url != "":
				song_option_container.show()
				regular_btn.show()
				if instrumental_download_url != "":
					instrumental_btn.show()
				else:
					instrumental_btn.hide()
				ncs_status_label.text = "Select a song version:"
				is_fetching_html = false
			else:
				_start_fallback_download()
		else:
			ncs_status_label.text = "Failed to load track page!"
			is_fetching_html = false

	else:
		if is_primary_download and not is_instrumental_download and (result != HTTPRequest.RESULT_SUCCESS or response_code != 200):
			print("Regular download failed. Falling back...")
			_start_fallback_download()
			return

		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var song_id = ncs_song_id_input.text.strip_edges()
			var save_directory = "user://songs/"
			var file_path = save_directory + song_id + ".mp3"
			
			if not DirAccess.dir_exists_absolute(save_directory):
				DirAccess.make_dir_absolute(save_directory)
				
			var file = FileAccess.open(file_path, FileAccess.WRITE)
			if file:
				file.store_buffer(body)
				file.close()
				ncs_status_label.text = "Saved to: " + file_path
				
			get_parent().save_manager.current_song_id = song_id
			get_parent().save_manager.load_song_to_editor(song_id)
			
			update_song_ui(
				get_parent().save_manager.current_song_name, 
				get_parent().save_manager.current_song_artist, 
				song_id
			)
		else:
			ncs_status_label.text = "Download failed! Code: " + str(response_code)

func _start_fallback_download() -> void:
	if fallback_mp3_url != "":
		ncs_status_label.text = "Downloading MP3..."
		get_parent().save_manager.current_song_name = fallback_title
		get_parent().save_manager.current_song_artist = fallback_artist
		
		is_fetching_html = false
		is_primary_download = false
		ncs_http_request.timeout = 0
		ncs_http_request.request(fallback_mp3_url)
	else:
		ncs_status_label.text = "MP3 link not found!"
		is_fetching_html = false

# NEWGROUNDS LOGIC
func _on_ng_get_button_pressed() -> void:
	var song_id = ng_song_id_input.text.strip_edges()
	if song_id != "":
		ng_status_label.text = "Fetching Newgrounds link..."
		is_ng_fetching_html = true
		var url = "https://www.newgrounds.com/audio/listen/" + song_id
		ng_http_request.request(url)

# Newgrounds http request
func _on_ng_http_request_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_ng_fetching_html:
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var html_string = body.get_string_from_utf8()
			
			# 1 & 2. Extract Title, Artist, and URL from NgAudioPlayer script payload
			var found_url = false
			
			if "NgAudioPlayer.fromListenPage({" in html_string:
				# Isolate the payload to avoid accidentally matching other parts of the page
				var payload = html_string.get_slice("NgAudioPlayer.fromListenPage({", 1)
				
				# Extract Author (Artist)
				if "'author': \"" in payload:
					ng_artist = payload.get_slice("'author': \"", 1).get_slice("\"", 0).xml_unescape()
				else:
					ng_artist = "Unknown"
					
				# Extract Title
				if "'title': \"" in payload:
					ng_title = payload.get_slice("'title': \"", 1).get_slice("\"", 0).xml_unescape()
				else:
					ng_title = "Unknown"
				
				# Extract URL and fix the escaped slashes (\/)
				if "'url': \"" in payload:
					var raw_url = payload.get_slice("'url': \"", 1).get_slice("\"", 0)
					ng_mp3_url = raw_url.replace("\\/", "/")
					found_url = true
			
			if found_url:
				ng_status_label.text = "Downloading Newgrounds MP3..."
				is_ng_fetching_html = false
				
				# Push metadata to save manager
				get_parent().save_manager.current_song_name = ng_title
				get_parent().save_manager.current_song_artist = ng_artist
				
				ng_http_request.timeout = 0
				ng_http_request.request(ng_mp3_url)
			else:
				ng_status_label.text = "Could not find MP3 file"
				is_ng_fetching_html = false
		else:
			ng_status_label.text = "Failed to load Newgrounds page"
			is_ng_fetching_html = false

	else:
		# 3. Save the actual MP3 bytes to user directory
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var song_id = ng_song_id_input.text.strip_edges()
			var save_directory = "user://songs/"
			var file_path = save_directory + song_id + ".mp3"
			
			if not DirAccess.dir_exists_absolute(save_directory):
				DirAccess.make_dir_absolute(save_directory)
				
			var file = FileAccess.open(file_path, FileAccess.WRITE)
			if file:
				file.store_buffer(body)
				file.close()
				ng_status_label.text = "Saved to: " + file_path
				
			get_parent().save_manager.current_song_id = song_id
			get_parent().save_manager._on_save_button_pressed()
			get_parent().save_manager.load_song_to_editor(song_id)
			
			update_song_ui(
				get_parent().save_manager.current_song_name, 
				get_parent().save_manager.current_song_artist, 
				song_id
			)
		else:
			ng_status_label.text = "Download failed! Code: " + str(response_code)

func update_song_ui(title: String, artist: String, id: String) -> void:
	song_name_label.text = "Song: " + title
	artist_label.text = "Artist: " + artist
	song_id_display.text = "ID: " + id
	
	# Update the unified play button
	play_music_btn.text = "Play"

func _on_play_button_pressed() -> void:
	_toggle_playback(play_music_btn)

# Unified play toggle logic so both tabs can use it
func _toggle_playback(btn_node: Button) -> void:
	var music_player = get_parent().get_node_or_null("LevelMusic")
	if music_player and music_player.stream != null:
		if music_player.playing:
			music_player.stop()
			btn_node.text = "Play"
		else:
			music_player.play()
			btn_node.text = "Stop"

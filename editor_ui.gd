extends CanvasLayer

# Edit action pressed
signal edit_action_requested(action_name: String)

# The build tab items
@onready var obstacles_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Obstacles
@onready var deco_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Decoration

# The edit tab items
@onready var actions_list: ItemList = $EditorPanel/MainTabContainer/Edit/Actions

var current_selected_objects: Array = []

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

# It stores the path so the main script can grab it when you click the canvas.
var selected_scene_path: String = ""

# 3. ADD THIS HELPER FUNCTION
# This takes the coordinates you provide and creates a sliced texture from your deco sheet
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
		
	load_images_from_folder($LevelSettingsMenu/GroundsContainer/Background, "res://Resources/Backgrounds")

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
				
				# Add to the ItemList just like your build menu!
				var index = target_list.add_item("", texture)
				target_list.set_item_metadata(index, full_path)
	else:
		print("Warning: Could not open folder at ", folder_path)

func _on_background_item_selected(index: int) -> void:
	# 1. Grab the specific ItemList node and ask it for the metadata at the clicked index
	var selected_path = $LevelSettingsMenu/GroundsContainer/Background.get_item_metadata(index)
	
	# 2. Send that retrieved string up to editor_root.gd
	get_parent().change_background(selected_path)

func _on_level_settings_button_pressed() -> void:
	$LevelSettingsMenu.visible = true
	get_parent().paused = true

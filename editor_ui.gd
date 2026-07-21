extends CanvasLayer

# Edit action pressed
signal edit_action_requested(action_name: String)

# The build tab items
@onready var obstacles_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Obstacles
@onready var deco_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Decoration

# The edit tab items
@onready var actions_list: ItemList = $EditorPanel/MainTabContainer/Edit/Actions

var current_selected_objects: Array = []

var item_database: Dictionary = {
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
			"icon": preload("res://Resources/Objects/star.png"),
			"scene_path": "res://scenes/objects/deco/star.tscn"
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

func _ready() -> void:
	populate_object_list(obstacles_list, item_database["obstacles"])
	populate_object_list(deco_list, item_database["deco"])
	populate_actions_tab()
	
	# Connect the Build tab's inner container like Obstacle, Deco, etc.
	var objects_container = $EditorPanel/MainTabContainer/Build/ObjectsContainer
	if objects_container is TabContainer:
		objects_container.tab_changed.connect(_on_objects_container_tab_changed)

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
	get_parent().paused = false

func update_selected_target(target_node):
	current_selected_objects = target_node

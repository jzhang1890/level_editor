extends CanvasLayer

# Edit action pressed
signal edit_action_requested(action_name: String)

# The build tab items
@onready var obstacles_list: ItemList = $EditorPanel/MainTabContainer/Build/ObjectsContainer/Obstacles

# The edit tab items
@onready var actions_list: ItemList = $EditorPanel/MainTabContainer/Edit/Actions

var item_database: Dictionary = {
	"obstacles": [
		{
			"name": "Black Hole",
			"icon": preload("res://Sprites/Icons/black_hole.svg"),
			"scene_path": "res://scenes/objects/black_hole.tscn"
		},
		{
			"name": "Meteor",
			"icon": preload("res://Sprites/Icons/meteor.svg"),
			"scene_path": "res://scenes/objects/meteor.tscn"
		},
		{
			"name": "Block",
			"icon": preload("res://Sprites/Icons/block1.svg"), 
			"scene_path": "res://scenes/objects/block.tscn"
		}
	]
}

# Define your buttons (Make sure to update the icon paths to match your actual files!)
var edit_actions: Array = [
	{"icon": preload("res://Sprites/Icons/move_up.svg"), "action": "move_up_tiny"},
	{"icon": preload("res://Sprites/Icons/move_down.svg"), "action": "move_down_tiny"},
	{"icon": preload("res://Sprites/Icons/move_left.svg"), "action": "move_left_tiny"},
	{"icon": preload("res://Sprites/Icons/move_right.svg"), "action": "move_right_tiny"},
	{"icon": preload("res://icon.svg"), "action": "rotate_left"},
	{"icon": preload("res://icon.svg"), "action": "rotate_right"}
]

# It stores the path so the main script can grab it when you click the canvas.
var selected_scene_path: String = ""

func _ready() -> void:
	populate_object_list(obstacles_list, item_database["obstacles"])
	populate_actions_tab()

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

func _on_object_item_selected(index: int) -> void:
	# Update the variable so the placement script knows what to build
	selected_scene_path = obstacles_list.get_item_metadata(index)
	print("Ready to place object from path: ", selected_scene_path)
	
func _on_actions_item_selected(index: int) -> void:
	var action_name = actions_list.get_item_metadata(index)
	
	# Shout out to the main script that a button was pressed
	edit_action_requested.emit(action_name)
	
	# Instantly deselect the item so it acts like a clickable button instead of a toggle
	actions_list.deselect_all()

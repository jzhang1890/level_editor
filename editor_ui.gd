extends CanvasLayer

@onready var obstacles_list: ItemList = $ObjectBrowser/Tabs/Obstacles

var spawnable_items: Array = [
	{
		"name": "Block",
		"icon": preload("res://Sprites/Icons/block1.svg"), 
		"scene_path": "res://scenes/objects/block.tscn"
	},
	{
		"name": "Black Hole",
		"icon": preload("res://Sprites/Icons/black_hole.svg"),
		"scene_path": "res://scenes/objects/black_hole.tscn"
	},
	{
		"name": "Meteor",
		"icon": preload("res://Sprites/Icons/meteor.svg"),
		"scene_path": "res://scenes/objects/meteor.tscn"
	}
]

# It stores the path so the main script can grab it when you click the canvas.
var selected_scene_path: String = ""

func _ready() -> void:
	populate_obstacles_tab()

func populate_obstacles_tab() -> void:
	obstacles_list.clear()
	
	for item in spawnable_items:
		var index = obstacles_list.add_item(item["name"], item["icon"])
		obstacles_list.set_item_metadata(index, item["scene_path"])

func _on_obstacles_item_selected(index: int) -> void:
	# Update the variable so the placement script knows what to build
	selected_scene_path = obstacles_list.get_item_metadata(index)
	print("Ready to place object from path: ", selected_scene_path)

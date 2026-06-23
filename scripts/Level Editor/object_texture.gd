extends TextureRect

@export var this_scene: PackedScene
@onready var object_cursor = get_node("/root/GameEditor/EditorObject")
@onready var cursor_sprite = object_cursor.get_node("Sprite")

# Called when the node enters the scene tree for the first time.
func _ready():
	gui_input.connect(_item_clicked)
	pass
	
func _item_clicked(event):
	if(event is InputEvent):
		if(event.is_action_pressed("mb_left")):
			object_cursor.current_item = this_scene
			cursor_sprite.texture = texture
	pass
			

extends Node2D

@export var room_width_x: float = 1024.0
@export var starting_height_y: float = 2048.0
@export var grid_size: float = 64.0 

@onready var camera: Camera2D = $"../../Camera2D" 

var current_top_y: float = 0.0

func _ready() -> void:
	current_top_y = -starting_height_y
	queue_redraw()

func _process(_delta: float) -> void:
	# Keep expanding the foreground canvas ahead of the camera
	if camera.position.y < current_top_y + 1500:
		current_top_y -= 1500 
		queue_redraw() # Redraw the expanding grid and walls

func _draw() -> void:

	# If camera zoom is 0.5, thickness becomes 2.0 in the world, staying 1.0 on screen
	var grid_thickness = 1.0 / camera.zoom.x
	var wall_thickness = 4.0 / camera.zoom.x
	var floor_thickness = 2.0 / camera.zoom.x
	
	var grid_color = Color(1.0, 1.0, 1.0, 0.15) 
	
	# Vertical Grid Lines
	var current_x = -room_width_x
	while current_x <= room_width_x:
		draw_line(Vector2(current_x, 0), Vector2(current_x, current_top_y), grid_color, grid_thickness)
		current_x += grid_size
		
	# Horizontal Grid Lines
	var current_y = 0.0
	while current_y >= current_top_y:
		draw_line(Vector2(-room_width_x, current_y), Vector2(room_width_x, current_y), grid_color, grid_thickness)
		current_y -= grid_size 

	# Main Border Walls using the dynamic wall_thickness
	draw_line(Vector2(-room_width_x, 0), Vector2(-room_width_x, current_top_y), Color.DARK_RED, wall_thickness)
	draw_line(Vector2(room_width_x, 0), Vector2(room_width_x, current_top_y), Color.DARK_RED, wall_thickness)
	draw_line(Vector2(-room_width_x, 0), Vector2(room_width_x, 0), Color.GRAY, floor_thickness)

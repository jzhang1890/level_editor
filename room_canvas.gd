extends Node2D

@export var room_width_x: float = 400.0 
@export var starting_height_y: float = 2000.0
@export var grid_size: float = 32.0 

@onready var camera: Camera2D = $"../../Camera2D" # Adjust path to find Camera2D

var current_top_y: float = 0.0

func _ready() -> void:
	current_top_y = -starting_height_y
	queue_redraw()

func _process(_delta: float) -> void:
	# Keep expanding the foreground canvas ahead of the camera
	if camera.position.y < current_top_y + 1000:
		current_top_y -= 1000 
		queue_redraw() # Redraw the expanding grid and walls

func _draw() -> void:
	# 1. DRAW THE FOREGROUND GRID (Moves at full 1.0 speed)
	var grid_color = Color(1.0, 1.0, 1.0, 0.15) 
	var line_thickness = 1.0
	
	# Vertical Grid Lines
	var current_x = -room_width_x
	while current_x <= room_width_x:
		draw_line(Vector2(current_x, 0), Vector2(current_x, current_top_y), grid_color, line_thickness)
		current_x += grid_size
		
	# Horizontal Grid Lines
	var current_y = 0.0
	while current_y >= current_top_y:
		draw_line(Vector2(-room_width_x, current_y), Vector2(room_width_x, current_y), grid_color, line_thickness)
		current_y -= grid_size 

	# 2. DRAW MAIN BORDER WALLS
	draw_line(Vector2(-room_width_x, 0), Vector2(-room_width_x, current_top_y), Color.DARK_RED, 4.0)
	draw_line(Vector2(room_width_x, 0), Vector2(room_width_x, current_top_y), Color.DARK_RED, 4.0)
	draw_line(Vector2(-room_width_x, 0), Vector2(room_width_x, 0), Color.GRAY, 2.0)

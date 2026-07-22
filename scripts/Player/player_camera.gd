extends Camera2D

@onready var player = $".."

var camera_locked: bool = false
var y_velocity: float = 0.0

# Percentage of the half-screen size before the camera starts shifting (0.8 = 80%)
@export_range(0.5, 0.95) var edge_threshold: float = 0.50

# How quickly the camera catches up to the player (Higher = faster camera)
@export var follow_speed: float = 5.0

# Remember the target position across frames
@onready var target_x: float = global_position.x

func _ready() -> void:
	# Severs the physical link to the parent node so camera follows script
	top_level = true

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	# Camera movement logic
	if camera_locked:
		# Smoothly ease the velocity down to 0 and apply it
		y_velocity = lerp(y_velocity, 0.0, 5.0 * delta)
		global_position.y += y_velocity * delta
	else:
		# 1. Keep the Y position locked perfectly to the player
		global_position.y = player.global_position.y
		# Constantly capture the player's speed so the camera knows how fast it was going when locked
		y_velocity = player.velocity.y 
	
	# 2. Calculate the visible horizontal boundary from the center
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var half_screen_width: float = (viewport_width / zoom.x) / 2.0
	var inner_boundary: float = half_screen_width * edge_threshold
	
	# 3. Find how far the player is from the camera's X center
	var distance_from_center: float = player.global_position.x - global_position.x
	
	# 4. Check if the player is pushing past the threshold AND moving in that direction
	var pushing_right: bool = distance_from_center > inner_boundary and player.velocity.x > 0
	var pushing_left: bool = distance_from_center < -inner_boundary and player.velocity.x < 0
	
	# Update the target destination only when the player pushes the boundaries
	if pushing_right:
		target_x = player.global_position.x - inner_boundary
	elif pushing_left:
		target_x = player.global_position.x + inner_boundary
		
	# Run the lerp unconditionally
	# The camera will smoothly glide to target_x, then settle.
	global_position.x = lerp(global_position.x, target_x, follow_speed * delta)

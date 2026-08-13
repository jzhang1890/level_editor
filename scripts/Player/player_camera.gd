extends Camera2D

@onready var player = $".."

var camera_locked: bool = false
var y_velocity: float = 0.0

var waiting_at_spawn: bool = true
var spawn_y: float = 0.0

var focusing_on_death: bool = false
var death_focus_y: float = 0.0

# Percentage of the half-screen size before the camera starts shifting (0.8 = 80%)
@export_range(0.5, 0.95) var edge_threshold: float = 0.50

# How quickly the camera catches up to the player (Higher = faster camera)
@export var follow_speed: float = 5.0

# Remember the target position across frames
@onready var target_x: float = global_position.x

func _ready() -> void:
	# Severs the link to the parent node so camera follows script
	top_level = true

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	# Hijack the camera to look at the missed orb
	if focusing_on_death:
		global_position.y = lerp(global_position.y, death_focus_y, follow_speed * delta)
		return # Skip the rest of normal player-tracking logic
		
	if camera_locked:
		# Smoothly ease the velocity down to 0 and apply it
		y_velocity = lerp(y_velocity, 0.0, 5.0 * delta)
		global_position.y += y_velocity * delta
	else:
		# WAITING FOR PLAYER LOGIC
		if waiting_at_spawn:
			# Lock the camera to the start position
			global_position.y = spawn_y
			
			# Check if the player has traveled high enough to cross the spawn line
			if player.global_position.y <= spawn_y:
				waiting_at_spawn = false
		else:
			# 1. Keep the Y position locked to the player
			global_position.y = player.global_position.y
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
	# The camera will glide to target_x, then settle.
	global_position.x = lerp(global_position.x, target_x, follow_speed * delta)

func focus_on_missed_orb(orb_y: float) -> void:
	focusing_on_death = true
	death_focus_y = orb_y

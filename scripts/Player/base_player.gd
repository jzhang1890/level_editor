extends CharacterBody2D
class_name BasePlayer

# Signal that shouts "player died" when the player dies
signal player_died

enum GameMode { SHIP, BALL }
var current_mode: GameMode = GameMode.BALL

@export var speedY := 450

var is_moving_x: bool = false

# Ball Variables
@export var ball_speedX := 1 # How much grids it moves
var ball_target_x: float = 0.0
@export var ball_max_speed: float = 1000.0
@export var ball_acceleration: float = 3000.0
@export var ball_deceleration: float = 2000.0
var ball_target_rotation: float = 0.0
@export var ball_rotation_speed: float = 15.0

# Ship Variables
@export var ship_speedX := 400 # Max horizontal speed
@export var ship_acceleration := 1200.0
@export var ship_deceleration := 1000.0
@export var ship_max_rotation: float = 0.2
@export var ship_rotation_speed: float = 1.0

var dead = false
var level_finished = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if dead:
		# Reset movement when dead
		is_moving_x = false 
		ball_target_rotation = 0.0 # Clear the ball target rotation
		return
		
	# Take away horizontal controls when the level is beat and slow down
	if level_finished:
		velocity.x = move_toward(velocity.x, 0.0, 2000 * delta) # Coast horizontally to a stop
		velocity.y = move_toward(velocity.y, -120.0, 150 * delta) # Hit the brakes until coasting at a slow speed
		
		# ROTATION HANDLING ON LEVEL END
		match current_mode:
			GameMode.SHIP:
				# Smoothly straighten the ship upright (0.0 rad)
				$Sprite2D.rotation = move_toward($Sprite2D.rotation, 0.0, ship_rotation_speed * delta)
			GameMode.BALL:
				# Keep interpolating the ball toward its target rotation
				$Sprite2D.rotation_degrees = lerp($Sprite2D.rotation_degrees, ball_target_rotation, ball_rotation_speed * delta)
		
		move_and_slide()
		return
		
	match current_mode:
		GameMode.BALL:
			process_ball(delta)
		GameMode.SHIP:
			process_ship(delta)
			
	# Move the body after the specific state has calculated the velocity
	move_and_slide()
	
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Obstacle and not $"..".noclip:
		dead = true
		player_died.emit()
		
func toggle_hitbox(is_hitbox_visible: bool) -> void:
	var hitbox = get_node_or_null("HitboxSprite")
	if hitbox:
		hitbox.visible = is_hitbox_visible
		
# BALL PHYSICS
func process_ball(delta: float) -> void:
	var clicked: bool = false
	
	if Input.is_action_just_pressed("right"):
		# Always base the new target on the current position, overriding the old one
		ball_target_x = global_position.x + (ball_speedX * 64.0) 
		
		# Base the new rotation target on the sprite's current angle
		ball_target_rotation = $Sprite2D.rotation_degrees + 90.0
		
		clicked = true
		
	elif Input.is_action_just_pressed("left"):
		# Always base the new target on the current position, overriding the old one
		ball_target_x = global_position.x - (ball_speedX * 64.0)
		
		# Base the new rotation target on the sprite's current angle
		ball_target_rotation = $Sprite2D.rotation_degrees - 90.0
		
		clicked = true

	if clicked:
		is_moving_x = true

	# 2 & 3. Kinematic Movement with Accel/Decel
	if is_moving_x:
		var distance_to_target = ball_target_x - global_position.x
		var dir = sign(distance_to_target)
		
		# NEW: Dynamically scale your physics based on how many grid tiles you are jumping
		var actual_max_speed = ball_max_speed * ball_speedX
		var actual_acceleration = ball_acceleration * ball_speedX
		var actual_deceleration = ball_deceleration * ball_speedX
		
		# Calculate if we need to start braking using d = v^2 / (2a)
		var stopping_distance = (velocity.x * velocity.x) / (2.0 * actual_deceleration)
		
		if abs(distance_to_target) <= stopping_distance:
			# Player is close enough; hit the brakes
			velocity.x = move_toward(velocity.x, 0.0, actual_deceleration * delta)
		else:
			# The player has room to speed up, so accelerate toward the target direction
			velocity.x = move_toward(velocity.x, dir * actual_max_speed, actual_acceleration * delta)
			
		# Snap to the grid and stop if we reach the target or overshoot
		if abs(distance_to_target) <= abs(velocity.x * delta) or (velocity.x == 0 and abs(distance_to_target) < 1.0):
			global_position.x = ball_target_x
			velocity.x = 0
			is_moving_x = false
	else:
		velocity.x = 0
		
	# 4. Standard vertical movement
	velocity.y = -speedY
	
	# Spin the sprite toward the target rotation every frame
	$Sprite2D.rotation_degrees = lerp($Sprite2D.rotation_degrees, ball_target_rotation, ball_rotation_speed * delta)
		
# SHIP PHYSICS
func process_ship(delta: float) -> void:
	var direction = Input.get_axis("left", "right")
	
	# If user is pressing a key, accelerate toward max speed
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * ship_speedX, ship_acceleration * delta)
	# If no key is pressed, decelerate back to 0
	else:
		velocity.x = move_toward(velocity.x, 0, ship_deceleration * delta)

	# Keep the constant upward movement
	velocity.y = -speedY
	
	# Rotation physics
	if direction > 0 and $Sprite2D.rotation < ship_max_rotation:
		$Sprite2D.rotation += ship_rotation_speed * delta
	elif direction < 0 and $Sprite2D.rotation > -ship_max_rotation:
		$Sprite2D.rotation -= ship_rotation_speed * delta
	elif direction == 0:
		if $Sprite2D.rotation < 0:
			$Sprite2D.rotation += ship_rotation_speed * delta
			if $Sprite2D.rotation > 0: $Sprite2D.rotation = 0
		elif $Sprite2D.rotation > 0:
			$Sprite2D.rotation -= ship_rotation_speed * delta
			if $Sprite2D.rotation < 0: $Sprite2D.rotation = 0

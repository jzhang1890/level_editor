extends CharacterBody2D
class_name BasePlayer

# Signal that shouts "player died" when the player dies
signal player_died

enum GameMode { SHIP, BALL }
var current_mode: GameMode = GameMode.BALL

@export var speedY := 400

var is_moving_x: bool = false

@export var noclip := false # noclip testing

# Ball Variables
@export var ball_speedX := 1 # How much grids it moves
var ball_target_x: float = 0.0
@export var ball_max_speed: float = 1000.0
@export var ball_acceleration: float = 3000.0
@export var ball_deceleration: float = 2000.0

# Ship Variables
@export var ship_speedX := 300 # Max horizontal speed
@export var ship_acceleration := 1200.0
@export var ship_deceleration := 800.0
@export var ship_max_rotation: float = 0.2
@export var ship_rotation_speed: float = 1.0

var dead = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if dead:
		# Reset ball movement when dead
		is_moving_x = false 
		return
		
	match current_mode:
		GameMode.BALL:
			process_ball(delta)
		GameMode.SHIP:
			process_ship(delta)
			
	# Move the body after the specific state has calculated the velocity
	move_and_slide()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Obstacle and not noclip:
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
		if not is_moving_x:
			ball_target_x = global_position.x
		ball_target_x += (ball_speedX * 64.0) # Add to the target, don't reset it
		clicked = true
		
	elif Input.is_action_just_pressed("left"):
		if not is_moving_x:
			ball_target_x = global_position.x
		ball_target_x -= (ball_speedX * 64.0)
		clicked = true

	if clicked:
		is_moving_x = true

	# 2 & 3. Kinematic Movement with Accel/Decel
	if is_moving_x:
		var distance_to_target = ball_target_x - global_position.x
		var dir = sign(distance_to_target)
		
		# Calculate if we need to start braking using d = v^2 / (2a)
		var stopping_distance = (velocity.x * velocity.x) / (2.0 * ball_deceleration)
		
		if abs(distance_to_target) <= stopping_distance:
			# We are close enough; hit the brakes
			velocity.x = move_toward(velocity.x, 0.0, ball_deceleration * delta)
		else:
			# We have room to speed up; accelerate toward the target direction
			velocity.x = move_toward(velocity.x, dir * ball_max_speed, ball_acceleration * delta)
			
		# Snap to the grid and stop if we reach the target or overshoot
		if abs(distance_to_target) <= abs(velocity.x * delta) or (velocity.x == 0 and abs(distance_to_target) < 1.0):
			global_position.x = ball_target_x
			velocity.x = 0
			is_moving_x = false
	else:
		velocity.x = 0
		
	# 4. Standard vertical movement
	velocity.y = -speedY
		
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

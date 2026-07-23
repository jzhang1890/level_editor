extends BasePlayer

@export var speedX := 1 # How much grids it moves

var target_x: float = 0.0
var is_moving_x: bool = false
@export var max_speed: float = 1000.0
@export var acceleration: float = 3000.0
@export var deceleration: float = 2000.0

func _physics_process(delta: float) -> void:
	# Force the state to reset when killed
	if dead:
		is_moving_x = false 
	
	if not dead:
		var clicked: bool = false
		
		if Input.is_action_just_pressed("right"):
			if not is_moving_x:
				target_x = global_position.x
			target_x += (speedX * 64.0) # Add to the target, don't reset it
			clicked = true
			
		elif Input.is_action_just_pressed("left"):
			if not is_moving_x:
				target_x = global_position.x
			target_x -= (speedX * 64.0)
			clicked = true

		if clicked:
			is_moving_x = true

		# 2 & 3. Kinematic Movement with Accel/Decel
		if is_moving_x:
			var distance_to_target = target_x - global_position.x
			var dir = sign(distance_to_target)
			
			# Calculate if we need to start braking using d = v^2 / (2a)
			var stopping_distance = (velocity.x * velocity.x) / (2.0 * deceleration)
			
			if abs(distance_to_target) <= stopping_distance:
				# We are close enough; hit the brakes
				velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
			else:
				# We have room to speed up; accelerate toward the target direction
				velocity.x = move_toward(velocity.x, dir * max_speed, acceleration * delta)
				
			# Snap to the grid and stop if we reach the target or overshoot
			if abs(distance_to_target) <= abs(velocity.x * delta) or (velocity.x == 0 and abs(distance_to_target) < 1.0):
				global_position.x = target_x
				velocity.x = 0
				is_moving_x = false
		else:
			velocity.x = 0
			
		# 4. Standard vertical movement
		velocity.y = -speedY
		move_and_slide()

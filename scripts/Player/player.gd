extends CharacterBody2D

# Add a signal that shouts "player died" when the player dies
signal player_died

@export var speedY := 400
@export var speedX := 300 # Max horizontal speed
@export var acceleration := 1200.0
@export var deceleration := 800.0
@export var noclip := false # noclip testing

@export var max_rotation: float = 0.2
@export var rotation_speed: float = 1.0

var dead = false

func _physics_process(delta: float) -> void:
	if not dead:
		var direction = Input.get_axis("left", "right")
		
		# If we are pressing a key, accelerate toward max speed
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * speedX, acceleration * delta)
		# If no key is pressed, decelerate back to 0
		else:
			velocity.x = move_toward(velocity.x, 0, deceleration * delta)

		# Keep the constant upward movement
		velocity.y = -speedY
		
		# No clip logic
		# If noclip is true, bypass move_and_slide() and manually shift position.
		if noclip:
			global_position += velocity * delta
		else:
			move_and_slide()

		# Rotation physics
		if direction > 0 and $Sprite2D.rotation < max_rotation:
			$Sprite2D.rotation += rotation_speed * delta
		elif direction < 0 and $Sprite2D.rotation > -max_rotation:
			$Sprite2D.rotation -= rotation_speed * delta
		elif direction == 0:
			if $Sprite2D.rotation < 0:
				$Sprite2D.rotation += rotation_speed * delta
				if $Sprite2D.rotation > 0: $Sprite2D.rotation = 0
			elif $Sprite2D.rotation > 0:
				$Sprite2D.rotation -= rotation_speed * delta
				if $Sprite2D.rotation < 0: $Sprite2D.rotation = 0
				
		# Collision detection is naturally skipped during noclip because move_and_slide() didn't run
		if get_slide_collision_count() > 0:
			var collision_info = get_slide_collision(0) 
			var collider = collision_info.get_collider()
			# Make sure Obstacles have a class name or belong to a group
			if collider is Obstacle:
				print("Physics movement hit an obstacle! Object name: ", collider.name)
				dead = true
				
				# Emits the signal outwards when the player dies
				player_died.emit()

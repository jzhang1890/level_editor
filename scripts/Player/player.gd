extends CharacterBody2D

# Add a signal that shouts "player died" when the player dies
signal player_died

@onready var spawn_position: Vector2 = global_position

@export var speedY := 400
@export var speedX := 300 # Max horizontal speed
@export var acceleration := 1200.0
@export var deceleration := 1200.0
@export var godmode := false

# --- NEW EXPORTS: Replaces your hardcoded 0.2 and 1.0 ---
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
		
		move_and_slide()

		# --- ADJUSTED: Using your new variables ---
		if direction > 0 and $PlayerSprite.rotation < max_rotation:
			$PlayerSprite.rotation += rotation_speed * delta
		elif direction < 0 and $PlayerSprite.rotation > -max_rotation:
			$PlayerSprite.rotation -= rotation_speed * delta
		elif direction == 0:
			if $PlayerSprite.rotation < 0:
				$PlayerSprite.rotation += rotation_speed * delta
				if $PlayerSprite.rotation > 0: $PlayerSprite.rotation = 0
			elif $PlayerSprite.rotation > 0:
				$PlayerSprite.rotation -= rotation_speed * delta
				if $PlayerSprite.rotation < 0: $PlayerSprite.rotation = 0
				
		if get_slide_collision_count() > 0 and not godmode:
			var collision_info = get_slide_collision(0) 
			var collider = collision_info.get_collider()
			# Make sure your Obstacles have a class name or belong to a group!
			if collider is Obstacle:
				print("Physics movement hit an obstacle! Object name: ", collider.name)
				dead = true
				
				# --- ADJUSTED: Emit the signal instead of calling a hardcoded parent ---
				player_died.emit()

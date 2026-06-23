extends CharacterBody2D

@onready var spawn_position: Vector2 = global_position
@onready var muzzle: Marker2D = $Muzzle

@export var projectile_scene: PackedScene

@export var speedY := 400
@export var speedX := 300
@export var godmode := false

# NEW: Cooldown variables
@export var fire_rate := 0.25 # The wait time in seconds before shooting again
var can_shoot := true
	
var dead = false

func _unhandled_input(event: InputEvent) -> void:
	# CHANGED: Now checks if the player is allowed to shoot based on the cooldown
	if event.is_action_pressed("shoot") and not dead and can_shoot:
		shoot()

func shoot() -> void:
	if projectile_scene:
		# 1. Disable shooting immediately so they can't spam
		can_shoot = false 
		
		# 2. Spawn the projectile
		var projectile = projectile_scene.instantiate()
		projectile.global_position = muzzle.global_position
		get_tree().current_scene.add_child(projectile)
		
		# 3. Create a temporary timer in code, wait for it to finish, then allow shooting
		await get_tree().create_timer(fire_rate).timeout
		can_shoot = true

func _ready() -> void:
	pass

# CHANGED: Moved from _process to _physics_process for accurate physics calculations
func _physics_process(delta: float) -> void:
	if not dead:
		var direction = Input.get_axis("left", "right")
		
		# 1. Direct assignment to the built-in velocity vector
		velocity = Vector2(direction * speedX, -speedY)
		
		# 2. Move using Godot's standard physics (it handles delta automatically!)
		move_and_slide()

		# Handle visual sprite rotation based on direction, not hardcoded keys ---
		if direction > 0 and $PlayerSprite.rotation < 0.2:
			# Moving Right
			$PlayerSprite.rotation += 1 * delta
		elif direction < 0 and $PlayerSprite.rotation > -0.2:
			# Moving Left
			$PlayerSprite.rotation -= 1 * delta
		elif direction == 0:
			# No horizontal input: Return to center
			if $PlayerSprite.rotation < 0:
				$PlayerSprite.rotation += 1 * delta
				# Prevent overshooting past 0
				if $PlayerSprite.rotation > 0: $PlayerSprite.rotation = 0
			elif $PlayerSprite.rotation > 0:
				$PlayerSprite.rotation -= 1 * delta
				# Prevent overshooting past 0
				if $PlayerSprite.rotation < 0: $PlayerSprite.rotation = 0
				
		# Old move_and_collide check replaced with Godot's slide collision check
		if get_slide_collision_count() > 0 and not godmode:
			var collision_info = get_slide_collision(0) # Get the first collision
			var collider = collision_info.get_collider()
			if collider is Obstacle:
				print("Physics movement hit a obstacle! Object name: ", collider.name)
				dead = true
				get_node("..").game_paused()

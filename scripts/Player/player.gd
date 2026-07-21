extends CharacterBody2D

# Signal that shouts "player died" when the player dies
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
		
		# If user is pressing a key, accelerate toward max speed
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * speedX, acceleration * delta)
		# If no key is pressed, decelerate back to 0
		else:
			velocity.x = move_toward(velocity.x, 0, deceleration * delta)

		# Keep the constant upward movement
		velocity.y = -speedY
		
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

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Obstacle and not noclip:
		dead = true
		player_died.emit()
		
func toggle_hitbox(is_visible: bool) -> void:
	var hitbox = get_node_or_null("HitboxSprite")
	if hitbox:
		hitbox.visible = is_visible

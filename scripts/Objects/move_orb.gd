extends Orb
class_name MoveOrb

@export var boost_amount: float = 800.0 # Tweak this in the inspector

func _process(_delta: float) -> void:
	# Check if a player is currently inside and the orb hasn't been used yet
	if player_inside != null and not triggered:
		
		# Listen for the directional inputs
		if Input.is_action_just_pressed("right"):
			apply_boost(1) # 1 represents positive X (Right)
		elif Input.is_action_just_pressed("left"):
			apply_boost(-1) # -1 represents negative X (Left)

func apply_boost(direction: int) -> void:
	triggered = true
	
	var burst_tween = create_tween()
	# Scale up by 50% over 0.2 seconds
	burst_tween.tween_property($Sprite2D, "scale", $Sprite2D.scale * 1.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Use parallel() to fade it invisible at the exact same time
	burst_tween.parallel().tween_property($Sprite2D, "modulate:a", 0.0, 0.2)
	
	# Apply the physical boost based on the current GameMode
	if player_inside.current_mode == BasePlayer.GameMode.SHIP:
		# Override the ship's current momentum with the massive boost
		player_inside.velocity.x = boost_amount * direction
		
	elif player_inside.current_mode == BasePlayer.GameMode.BALL:
		# The ball uses target grid snapping, so push its target far in the pressed direction
		player_inside.ball_target_x = player_inside.global_position.x + (boost_amount * direction * 0.1)
		player_inside.is_moving_x = true
		
	# Register this orb to the Play/Editor scene so it resets properly on death
	var current_level = get_tree().current_scene
	if "modified_objects" in current_level:
		current_level.modified_objects.append(self)

extends Orb
class_name MoveOrb

@export var boost_amount: float = 750.0 

func _process(_delta: float) -> void:
	if player_inside != null and not triggered:
		if Input.is_action_just_pressed("right"):
			apply_boost(1) 
		elif Input.is_action_just_pressed("left"):
			apply_boost(-1) 

func apply_boost(direction: int) -> void:
	triggered = true
	
	# Fix: Kill the base hover tween so it doesn't get orphaned
	if scale_tween:
		scale_tween.kill()
	
	# Reuse the base class tween so it can be killed on reset
	scale_tween = create_tween()
	scale_tween.tween_property($Sprite2D, "scale", $Sprite2D.scale * 1.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.parallel().tween_property($Sprite2D, "modulate:a", 0.0, 0.2)
	
	player_inside.velocity.x = boost_amount * direction
		
	if player_inside.current_mode == BasePlayer.GameMode.BALL:
		player_inside.is_moving_x = true

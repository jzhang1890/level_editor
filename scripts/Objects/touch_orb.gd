extends Orb
class_name TouchOrb

func _on_player_entered() -> void:
	if not triggered:
		triggered = true
		
		# Fix: Kill the base hover tween so it doesn't get orphaned
		if scale_tween:
			scale_tween.kill()
		
		# Reuse the base class tween so it can be killed on reset
		scale_tween = create_tween()
		scale_tween.tween_property($Sprite2D, "scale", $Sprite2D.scale * 1.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scale_tween.parallel().tween_property($Sprite2D, "modulate:a", 0.0, 0.2)
		
		# Put your instant effect on the player here

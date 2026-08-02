extends Orb
class_name TouchOrb

# Overrides the virtual function from the base Orb class
func _on_player_entered() -> void:
	if not triggered:
		# print("Orb triggered")
		triggered = true
		
		var burst_tween = create_tween()
		# Scale up by 50% over 0.2 seconds
		burst_tween.tween_property($Sprite2D, "scale", $Sprite2D.scale * 1.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Use parallel() to fade it invisible at the exact same time
		burst_tween.parallel().tween_property($Sprite2D, "modulate:a", 0.0, 0.2)
		# Put your instant effect on the player here

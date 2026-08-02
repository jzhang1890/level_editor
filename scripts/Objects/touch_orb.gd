extends Orb
class_name TouchOrb

# Overrides the virtual function from the base Orb class
func _on_player_entered() -> void:
	if not triggered:
		# print("Orb triggered")
		triggered = true
		# Put your instant effect on the player here

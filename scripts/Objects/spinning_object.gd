extends Sprite2D

@export var spin_speed: float = 120

func _process(delta: float) -> void:
	# Calculate the deterministic rotation
	rotation_degrees += spin_speed * delta

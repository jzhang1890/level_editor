extends Area2D

@export var speed := 600.0


func _physics_process(delta: float) -> void:
	# global_position guarantees it travels UP on the screen
	global_position.y -= (get_node("../Player").speedY + speed) * delta 

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()
	queue_free()

# NEW: Godot added this when you connected the signal
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

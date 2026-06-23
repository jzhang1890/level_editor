extends Node2D
class_name GameLevel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func game_paused():
	get_tree().paused = true
	get_node("InGameOverlay").hide()
	get_node("GameOverlay").show()
	
func game_resume():
	get_tree().paused = false
	get_node("InGameOverlay").show()
	get_node("GameOverlay").hide()
	

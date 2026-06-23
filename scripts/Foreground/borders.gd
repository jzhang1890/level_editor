extends Node2D

@onready var player: CharacterBody2D = get_node("../Player") 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	global_position.y = player.global_position.y

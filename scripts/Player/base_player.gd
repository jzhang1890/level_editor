extends CharacterBody2D
class_name BasePlayer

# Signal that shouts "player died" when the player dies
signal player_died

@export var speedY := 400

@export var noclip := false # noclip testing

var dead = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Obstacle and not noclip:
		dead = true
		player_died.emit()
		
func toggle_hitbox(is_hitbox_visible: bool) -> void:
	var hitbox = get_node_or_null("HitboxSprite")
	if hitbox:
		hitbox.visible = is_hitbox_visible

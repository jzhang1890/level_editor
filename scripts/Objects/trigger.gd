class_name Trigger
extends Area2D

# Standard properties every trigger will share
var is_triggered: bool = false
@export var trigger_once: bool = true

# The toggle for your future feature
@export var use_hitbox: bool = false

func _ready() -> void:
	
	# Let the editor know this is a generic trigger
	if not has_meta("is_trigger"):
		set_meta("is_trigger", true)
	
	# Hook up the physical collision check for the future
	body_entered.connect(_on_body_entered)

# Turns the green selection tint on/off
func set_highlight(active: bool) -> void:
	if active:
		$Sprite2D.modulate = Color(0.5, 1.5, 0.5) 
	else:
		$Sprite2D.modulate = Color(1, 1, 1, 1)


# The child classes will overwrite this with their own unique math.
func fire_trigger() -> void:
	pass

# Hook this up to your death/respawn manager later
func reset() -> void:
	is_triggered = false

func _on_body_entered(body: Node2D) -> void:
	# We only care about physical collisions if the toggle is checked
	if use_hitbox and body.name == "Player" and not is_triggered:
		if trigger_once:
			is_triggered = true
		fire_trigger()

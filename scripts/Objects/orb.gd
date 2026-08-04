extends Area2D
class_name Orb

var base_position: Vector2
var base_sprite_scale: Vector2 # Stores original size
var triggered: bool = false

# Keeps track of the animation so it can be interrupted safely
var scale_tween: Tween 

# Tracks the player while they are inside the orb's collision shape
var player_inside: BasePlayer = null

func _ready() -> void:
	# Add this orb to a global group so the player can find it
	add_to_group("orbs")
	# Anchor the starting position the moment the level loads
	base_position = global_position
	# Anchor the starting scale
	base_sprite_scale = $Sprite2D.scale
	
	# Connect signals to track the player's hitbox
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func reset() -> void:
	global_position = base_position
	triggered = false 
	
	# Reset the scale instantly and kill any running animations
	if scale_tween:
		scale_tween.kill()
	$Sprite2D.scale = base_sprite_scale
	
	# Reset the full color, not just the alpha
	$Sprite2D.modulate = Color(1, 1, 1, 1)

# Turns the green selection tint on/off for the editor
func set_highlight(active: bool) -> void:
	if active:
		$Sprite2D.modulate = Color(0.5, 1.5, 0.5) 
	else:
		$Sprite2D.modulate = Color(1, 1, 1, 1)

func _on_area_entered(area: Area2D) -> void:
	# Ignore death line
	if area.name == "TrailingDeathLine":
		return
	
	if area.get_parent() is BasePlayer:
		player_inside = area.get_parent()
		
		# Register the orb immediately so hover animations always reset 
		var current_level = get_tree().current_scene
		if "modified_objects" in current_level and not self in current_level.modified_objects:
			current_level.modified_objects.append(self)
			
		# Only do the hover animation if the orb hasn't been used yet
		if not triggered:
			# Stop shrinking if currently shrinking
			if scale_tween:
				scale_tween.kill() 
				
			# Animate the Sprite2D getting 30% larger over 0.2 seconds
			scale_tween = create_tween()
			scale_tween.tween_property($Sprite2D, "scale", base_sprite_scale * 1.3, 0.2).set_trans(Tween.TRANS_SINE)
		
		# Call a virtual function that child classes can use
		_on_player_entered()

func _on_area_exited(area: Area2D) -> void:
	# Ignore death line
	if area.name == "TrailingDeathLine":
		return
	if area.get_parent() is BasePlayer:
		player_inside = null
		
		# Only do the shrink animation if the orb hasn't been used yet
		if not triggered:
			# Stop growing if currently growing
			if scale_tween:
				scale_tween.kill() 
				
			# Animate the Sprite2D shrinking back to normal over 0.25 seconds
			scale_tween = create_tween()
			scale_tween.tween_property($Sprite2D, "scale", base_sprite_scale, 0.25).set_trans(Tween.TRANS_SINE)
		
		# Call a virtual function that child classes can use
		_on_player_exited()

func show_missed_warning() -> void:
	var blink_tween = create_tween().set_loops(2)
	# Modulate to red
	blink_tween.tween_property($Sprite2D, "modulate", Color(1, 0, 0, 1), 0.15)
	
	# Just tween back to white
	blink_tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1, 1), 0.15)

# Virtual Function for subclasses
# These do nothing here, but allow child classes to easily inject their own logic

func _on_player_entered() -> void:
	pass

func _on_player_exited() -> void:
	pass

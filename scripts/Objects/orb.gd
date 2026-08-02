extends Area2D
class_name Orb

var base_position: Vector2
var base_sprite_scale: Vector2 # Stores original size
var triggered: bool = false

# Keeps track of the animation so we can interrupt it safely
var scale_tween: Tween 

# Tracks the player while they are inside the orb's collision shape
var player_inside: BasePlayer = null

func _ready() -> void:
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

# Turns the green selection tint on/off for the editor
func set_highlight(active: bool) -> void:
	if active:
		$Sprite2D.modulate = Color(0.5, 1.5, 0.5) 
	else:
		var current_channel = get_meta("color_channel", 0)
		$Sprite2D.modulate = Global.get_channel_color(current_channel)

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() is BasePlayer:
		player_inside = area.get_parent()
		
		# Stop shrinking if currently shrinking
		if scale_tween:
			scale_tween.kill() 
			
		# Animate the Sprite2D getting 30% larger over 0.2 seconds
		scale_tween = create_tween()
		scale_tween.tween_property($Sprite2D, "scale", base_sprite_scale * 1.3, 0.2).set_trans(Tween.TRANS_SINE)
		
		# Call a virtual function that child classes can use
		_on_player_entered()

func _on_area_exited(area: Area2D) -> void:
	if area.get_parent() is BasePlayer:
		player_inside = null
		
		# Stop growing if currently growing
		if scale_tween:
			scale_tween.kill() 
			
		# Animate the Sprite2D shrinking back to normal over 0.25 seconds
		scale_tween = create_tween()
		scale_tween.tween_property($Sprite2D, "scale", base_sprite_scale, 0.25).set_trans(Tween.TRANS_SINE)
		
		# Call a virtual function that child classes can use
		_on_player_exited()

# --- VIRTUAL FUNCTIONS FOR SUBCLASSES ---
# These do nothing here, but allow child classes to easily inject their own logic

func _on_player_entered() -> void:
	pass

func _on_player_exited() -> void:
	pass

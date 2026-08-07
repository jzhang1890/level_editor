extends Trigger

var player_ref: CharacterBody2D = null
var active_tween: Tween = null 

func _ready() -> void:
	super._ready()
	add_to_group("color_triggers")
	
	# Only set defaults if the save manager hasn't already injected data
	if not has_meta("is_color_trigger"):
		set_meta("is_color_trigger", true)
		
	if not has_meta("target_channel"):
		set_meta("target_channel", 0)
		
	if not has_meta("trigger_color"):
		set_meta("trigger_color", Color(1, 1, 1, 1))
		
	if not has_meta("fade_time"):
		set_meta("fade_time", 0.0)

func _process(_delta: float) -> void:
	# 1. If don't have the player yet, try to find them
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		
	# 2. If it is still null (not playtesting), stop here
	if use_hitbox or is_triggered or not is_instance_valid(player_ref):
		return
		
	# 3. Mathematical Y-check
	if player_ref.global_position.y <= global_position.y:
		if trigger_once:
			is_triggered = true
		fire_trigger()

# Override the reset function to kill the rogue tween
func reset() -> void:
	super.reset() # Call the parent Trigger's reset logic so the trigger can be fired again
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()

func fire_trigger() -> void:
	var channel = get_meta("target_channel", 0)
	
	# Broadcast to the whole group to kill running tweens on this specific channel
	get_tree().call_group("color_triggers", "interrupt_active_tween", channel)
	
	var trigger_color = get_meta("trigger_color", Color(1, 1, 1, 1))
	var fade = get_meta("fade_time", 0.0)
	
	if fade <= 0.0:
		# Instantaneous transition
		Global.active_level_colors[channel] = trigger_color
		
		# 1. Consolidate the scene lookup to remove duplicate code
		var main_scene = get_tree().get_first_node_in_group("level_editor")
		if main_scene == null:
			main_scene = get_tree().get_first_node_in_group("play_scene")
			
		if main_scene != null:
			# Add to the reset list
			if not main_scene.modified_objects.has(self):
				main_scene.modified_objects.append(self)
				
			# 2. Grab the chunks directly from the active scene
			var level_chunks = main_scene.level_chunks
			var active_chunks = main_scene.active_chunks
			
			# 3. Sweep active chunks and apply the color
			for chunk_id in active_chunks:
				if level_chunks.has(chunk_id):
					for obj in level_chunks[chunk_id]:
						if is_instance_valid(obj):
							if obj is Trigger or obj.has_meta("ignore_color"):
								continue
								
							if obj.get_meta("color_channel", 0) == channel:
								if obj is Sprite2D:
									obj.modulate = trigger_color
								else:
									var sprite = obj.get_node_or_null("Sprite2D")
									if sprite:
										sprite.modulate = trigger_color
									else:
										# Fallback for obstacles without a Sprite2D child
										obj.modulate = trigger_color
	else:
			# Smooth transition
			var main_scene = get_tree().get_first_node_in_group("level_editor")
			if main_scene == null:
				main_scene = get_tree().get_first_node_in_group("play_scene")
				
			if main_scene != null:
				# Add to the reset list
				if not main_scene.modified_objects.has(self):
					main_scene.modified_objects.append(self)
					
				# Grab the current color as starting point
				var start_color = Global.get_channel_color(channel)
				
				# Assign the tween to the tracking variable
				active_tween = create_tween()
				active_tween.tween_method(_on_fade_step.bind(channel, main_scene), start_color, trigger_color, fade)

func _on_fade_step(current_color: Color, target_channel: int, main_scene: Node) -> void:
	# 1. Update the global color so any sleeping chunks wake up with the precise intermediate color
	Global.active_level_colors[target_channel] = current_color
	
	# 2. Sweep the currently active chunks and update them
	if is_instance_valid(main_scene):
		var level_chunks = main_scene.level_chunks
		var active_chunks = main_scene.active_chunks
		
		for chunk_id in active_chunks:
			if level_chunks.has(chunk_id):
				for obj in level_chunks[chunk_id]:
					if is_instance_valid(obj):
						if obj is Trigger or obj.has_meta("ignore_color"):
							continue
							
						if obj.get_meta("color_channel", 0) == target_channel:
							if obj is Sprite2D:
								obj.modulate = current_color
							else:
								var sprite = obj.get_node_or_null("Sprite2D")
								if sprite:
									sprite.modulate = current_color
								else:
									# Fallback for obstacles without a Sprite2D child
									obj.modulate = current_color
									
func interrupt_active_tween(incoming_channel: int) -> void:
	# Check if the broadcast channel matches this trigger's target channel
	if get_meta("target_channel", 0) == incoming_channel:
		# Kill the tween if it is currently running
		if active_tween and active_tween.is_valid():
			active_tween.kill()

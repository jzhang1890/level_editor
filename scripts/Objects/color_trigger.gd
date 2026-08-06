extends Trigger

var player_ref: CharacterBody2D = null

func _ready() -> void:
	super._ready()
	
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
	# 1. If we don't have the player yet, try to find them
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		
	# 2. If it is still null (meaning we are not playtesting), stop here
	if use_hitbox or is_triggered or not is_instance_valid(player_ref):
		return
		
	# 3. Mathematical Y-check
	if player_ref.global_position.y <= global_position.y:
		if trigger_once:
			is_triggered = true
		fire_trigger()

func fire_trigger() -> void:
	var channel = get_meta("target_channel", 0)
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
		# TODO: We'll put a Tween in here when you want to add the fade
		pass

# Inside your future Move Trigger script:

func trigger_activated() -> void:
	# (Math to move the target_block goes here)
	
	# Tell the main scene this block has been changed!
	var main_scene = get_tree().current_scene
	if not main_scene.modified_objects.has(target_block):
		main_scene.modified_objects.append(target_block)

extends Node

# Stores the path of the level the user clicked on
var level_to_load: String = ""

var active_level_colors: Dictionary = {}

func reset_colors() -> void:
	active_level_colors.clear()

func get_channel_color(channel_id: int) -> Color:
	# Check if the channel exists in our dictionary
	if active_level_colors.has(channel_id):
		return active_level_colors[channel_id]
	
	# If nothing is saved yet, fallback to white
	return Color.WHITE

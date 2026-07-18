extends Node2D

@onready var level_canvas: Node2D = $LevelCanvas
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D

# For the background texture
@onready var bg_rect: TextureRect = $BackgroundCanvas/BackgroundLayer/Background

@onready var pause_menu: ColorRect = $GameOverlay/PauseMenu

@onready var level_name_label: Label = $GameOverlay/PauseMenu/LevelNameLabel

@export var hitboxes_on := false

var restart_button_pressed = false

# --- CHUNKING VARIABLES ---
const CHUNK_HEIGHT: float = 256.0 # Screen height
var level_chunks: Dictionary = {} 
var active_chunks: Array = [] 
var last_calculated_chunk: int = -999

# Level name duh
var level_name = ""

var paused = false

var spawn_position: Vector2 = Vector2.ZERO

var respawn_time = 1

# Array to track objects altered by triggers or gameplay
var modified_objects: Array[Obstacle] = []

func _ready() -> void:
	
	# After loading the level
	spawn_position = player.global_position
	
	# Hides menu
	if pause_menu:
		pause_menu.visible = false
	
	# 1. Grab the level path from your Global script
	if Global.level_to_load != "":
		load_level(Global.level_to_load)
	
	# Lock and hide the mouse so it stops generating motion events
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Tell the engine to completely stop checking the mouse against collision objects
	get_viewport().physics_object_picking = false
	
	# 2.  FOR LATER: Set the player's starting position based on level data for spawn points

func _unhandled_input(event: InputEvent) -> void:
	# Check if the player pressed ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if paused:
			_on_resume_button_pressed()
		else:
			_on_pause_button_pressed()

# Loading level function
func load_level(target_path: String) -> void:
	if not FileAccess.file_exists(target_path):
		print("No save file found at: ", target_path)
		return

	for child in level_canvas.get_children():
		child.queue_free()
	
	# Clear chunks before loading
	level_chunks.clear()
	active_chunks.clear()
	last_calculated_chunk = -999
	
	var file = FileAccess.open(target_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var level_data = JSON.parse_string(json_string)
		
		# Check if the data is the Dictionary format
		if typeof(level_data) == TYPE_DICTIONARY and level_data.has("items"):
			
			# Load and apply the background
			if level_data.has("background"):
				var current_bg_path = level_data["background"]
				var loaded_texture = load(current_bg_path)
				if loaded_texture:
					bg_rect.texture = loaded_texture
					
			if level_data.has("level_name"):
				level_name = level_data["level_name"]
				level_name_label.text = level_name
			
			var items_raw = level_data["items"]
			
			# Ensure we are reading the new compressed string format
			if typeof(items_raw) == TYPE_STRING:
				var item_strings = items_raw.split(";")
				
				# --- NEW: Setup our caches ---
				var scene_cache: Dictionary = {}
				var deco_batches: Dictionary = {}
				
				# Loop through the objects in the compressed string
				for item_str in item_strings:
					if item_str.is_empty():
						continue
						
					var data = item_str.split(",")
					if data.size() < 2:
						continue
						
					# Setup our baseline default values
					var item_dict = {
						"rotation": 0.0,
						"scale_x": 1.0,
						"scale_y": 1.0,
						"layer": 1
					}
					
					# Read through array in pairs (key, value)
					for i in range(0, data.size(), 2):
						if i + 1 >= data.size():
							break
						var key = data[i]
						var val = data[i+1]
						
						match key:
							"1": item_dict["id"] = val
							"2": item_dict["scene_path"] = val
							"3": item_dict["x"] = val.to_float()
							"4": item_dict["y"] = val.to_float()
							"5": item_dict["rotation"] = val.to_float()
							"6": item_dict["scale_x"] = val.to_float()
							"7": item_dict["scale_y"] = val.to_float()
							"8": item_dict["layer"] = val.to_int()
							"9": item_dict["skew"] = val.to_float()
							
					# --- THE FILTER INTERCEPT ---
					var path = item_dict["scene_path"]
					
					# Check if the path contains our new Deco folder
					if "/deco/" in path.to_lower():
						# Group them by path AND layer so depth sorting still works
						var layer = item_dict.get("layer", 1)
						var batch_key = path + "_" + str(layer)
						
						if not deco_batches.has(batch_key):
							deco_batches[batch_key] = {
								"path": path,
								"layer": layer,
								"transforms": []
							}
							
						# Build the raw math matrix (Transform2D) for the GPU
						var rot_rad = deg_to_rad(item_dict.get("rotation", 0.0))
						var pos = Vector2(item_dict.get("x", 0.0), item_dict.get("y", 0.0))
						var obj_scale = Vector2(item_dict.get("scale_x", 1.0), item_dict.get("scale_y", 1.0))

						# 1. Grab the skew from the dictionary (defaults to 0.0 if not found)
						var obj_skew = item_dict.get("skew", 0.0) 

						# 2. Invert the local Y scale to counteract the QuadMesh 3D axis flip
						obj_scale.y *= -1.0 

						# 3. Use the Godot 4 master constructor: Transform2D(rotation, scale, skew, origin)
						# Feed it Vector2.ZERO for the origin first so it flips and skews locally!
						var gpu_transform = Transform2D(rot_rad, obj_scale, obj_skew, Vector2.ZERO)

						# 4. Add the position in AFTER the transform is built
						gpu_transform.origin = pos

						# Add it to the array and skip instantiation completely
						deco_batches[batch_key]["transforms"].append(gpu_transform)
						continue # Skip the rest of the loop so it doesn't become a node

					# ONLY HAZARDS AND TRIGGERS MAKE IT PAST THE CONTINUE
					
					# Check cache before hitting the hard drive
					if not scene_cache.has(path):
						scene_cache[path] = load(path)
						
					# Instantiate the object using the cache
					var resource = scene_cache[path]
					if resource:
						var new_object = resource.instantiate()
						
						# Position of object
						new_object.global_position = Vector2(item_dict["x"], item_dict["y"])
						
						# Apply rotation and store base_rotation for spinning objects
						var loaded_rot = item_dict["rotation"]
						new_object.rotation_degrees = loaded_rot
						new_object.set_meta("base_rotation", loaded_rot)
						
						# Apply scale
						new_object.scale = Vector2(item_dict["scale_x"], item_dict["scale_y"])
						
						# Apply skew
						new_object.skew = item_dict.get("skew", 0.0)
						
						# Apply the saved ID
						new_object.set_meta("unique_id", item_dict["id"])
						
						# Use the layer to determine z-index
						var loaded_layer = item_dict["layer"]
						new_object.z_index = -loaded_layer
						
						var chunk_id = int(floor(new_object.global_position.y / CHUNK_HEIGHT))
						
						# 1. Create an empty array for this chunk if it doesn't exist yet
						if not level_chunks.has(chunk_id):
							level_chunks[chunk_id] = []
							
						# 2. Add the object to the main canvas to preserve chronological layering
						level_canvas.add_child(new_object)
						level_chunks[chunk_id].append(new_object)
						
						# 3. Sleep the object immediately if it's not in an active chunk
						if chunk_id not in active_chunks:
							new_object.process_mode = Node.PROCESS_MODE_DISABLED
							new_object.visible = false
				
				# BATCH GENERATE THE MULTIMESHES ONCE THE LOOP IS DONE
				for batch_key in deco_batches:
					var batch_data = deco_batches[batch_key]
					var deco_path = batch_data["path"]
					var transforms = batch_data["transforms"]
					
					# Load the scene ONCE to steal its texture
					var dummy_scene = load(deco_path).instantiate()
					var tex = null
					
					# Grab the texture whether it's on the root node or a Sprite2D child
					if "texture" in dummy_scene and dummy_scene.texture != null:
						tex = dummy_scene.texture
					elif dummy_scene.has_node("Sprite2D"):
						tex = dummy_scene.get_node("Sprite2D").texture
						
					dummy_scene.queue_free()
					
					if tex:
						# Create the GPU mesh matched to the image size
						var quad = QuadMesh.new()
						quad.size = tex.get_size()
						
						var mm = MultiMesh.new()
						mm.mesh = quad
						mm.use_colors = false
						mm.instance_count = transforms.size()
						
						# Dump all the coordinates into the GPU buffer natively
						for i in range(transforms.size()):
							mm.set_instance_transform_2d(i, transforms[i])
							
						var mm_inst = MultiMeshInstance2D.new()
						mm_inst.multimesh = mm
						mm_inst.texture = tex
						mm_inst.z_index = -batch_data["layer"]
						
						# Add the single MultiMesh to the canvas
						level_canvas.add_child(mm_inst)
					
func _process(_delta: float) -> void:
	if paused:
		return
		
	# Check where the camera currently is on the Y-axis
	var current_camera_chunk = int(floor(camera.global_position.y / CHUNK_HEIGHT))
	
	# If we crossed into a new chunk, run the update
	if current_camera_chunk != last_calculated_chunk:
		update_chunks(current_camera_chunk)
		last_calculated_chunk = current_camera_chunk

func _on_player_player_died() -> void:
	if not restart_button_pressed:
		await get_tree().create_timer(respawn_time, false).timeout
	
	# Reset player
	$Player/Sprite2D.rotation = 0
	player.global_position = spawn_position
	player.velocity = Vector2(0, player.speedY)
	player.dead = false
	
	# Reset camera
	camera.global_position = spawn_position 
	camera.target_x = spawn_position.x 
	
	# Force the chunks to reset instantly on respawn 
	last_calculated_chunk = -999 
	
	# Optimization
	# Only iterate through objects that were actually moved
	for obj in modified_objects:
		if is_instance_valid(obj):
			obj.reset()
	
	# Clear the list so it doesn't cause a memory leak freeze
	modified_objects.clear()
	restart_button_pressed = false
	
func _on_pause_button_pressed() -> void:
	# Shows name of level
	if level_name_label:
		level_name_label.text = level_name
		
	# Reveal the menu
	if pause_menu:
		pause_menu.visible = true
	paused = true
	
	# Bring the mouse back so the user can click the menu buttons
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Pauses the game
	get_tree().paused = true


func _on_resume_button_pressed() -> void:
	# Hide the menu to resume game
	if pause_menu:
		pause_menu.visible = false
	paused = false	
	
	# Lock and hide the mouse again for gameplay because of lag
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	get_tree().paused = false
	
func _on_restart_button_pressed() -> void:
	restart_button_pressed = true
	_on_resume_button_pressed()
	_on_player_player_died()
	
func _on_quit_button_pressed() -> void:
	# Return to Level Browser scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/rooms/level_details.tscn")
	
# CHUNK MANAGER
func update_chunks(center_chunk: int) -> void:
	# How many chunks up and down to load. 
	# A radius of 4 means 4 above, 4 below, and the center (9 total).
	var render_radius: int = 3
	
	var needed_chunks: Array[int] = []
	for i in range(-render_radius, render_radius + 1):
		needed_chunks.append(center_chunk + i)

	# Always keep the spawn chunks loaded to prevent blinking 
	var current_spawn_chunk = int(floor(spawn_position.y / CHUNK_HEIGHT))
	
	var spawn_chunks: Array[int] = []
	for i in range(-render_radius, render_radius + 1):
		spawn_chunks.append(current_spawn_chunk + i)
	
	for c in spawn_chunks:
		if not needed_chunks.has(c):
			needed_chunks.append(c)

	# 1. Sleep chunks that went off-screen
	for chunk_id in active_chunks:
		if chunk_id not in needed_chunks:
			if level_chunks.has(chunk_id):
				for obj in level_chunks[chunk_id]:
					if is_instance_valid(obj):
						obj.process_mode = Node.PROCESS_MODE_DISABLED
						obj.visible = false

	# 2. Wake up chunks coming on-screen
	for chunk_id in needed_chunks:
		if chunk_id not in active_chunks:
			if level_chunks.has(chunk_id):
				for obj in level_chunks[chunk_id]:
					if is_instance_valid(obj):
						obj.process_mode = Node.PROCESS_MODE_INHERIT
						obj.visible = true
						
						var hitbox = obj.get_node_or_null("HitboxSprite")
						if hitbox:
							hitbox.visible = hitboxes_on

	active_chunks = needed_chunks

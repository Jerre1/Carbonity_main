extends Node3D

@export var structures: Array[Structure] = []
@export var bubble_dict: Dictionary = {}

var map:DataMap

var index:int = 15 # Index of structure being built

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
@export var cash_display:Label

var plane:Plane # Used for raycasting mouse

var bubbles = preload("res://scenes/bubbles.tscn")

func _ready():
	
	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)
	
	# Create new MeshLibrary dynamically, can also be done in the editor
	# See: https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html
	
	var mesh_library = MeshLibrary.new()
	
	for structure in structures:
		
		var id = mesh_library.get_last_unused_item_id()
		
		mesh_library.create_item(id)
		mesh_library.set_item_mesh(id, get_mesh(structure.model))
		mesh_library.set_item_mesh_transform(id, Transform3D())
		
	gridmap.mesh_library = mesh_library
	
	update_structure()
	update_cash()
	action_load()

func _process(delta):
	
	# Controls
	
	action_rotate() # Rotates selection 90 degrees
	action_structure_toggle() # Toggles between structures
	
	
	action_load() # Loading
	action_save() # Saving
	
	# Map position based on mouse
	
	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(get_viewport().get_mouse_position()),
		view_camera.project_ray_normal(get_viewport().get_mouse_position()))

	var gridmap_position = Vector3(round(world_position.x), 0, round(world_position.z))
	selector.position = lerp(selector.position, gridmap_position, delta * 40)
	
	action_build(gridmap_position)
	action_demolish(gridmap_position)
	action_upgrade(gridmap_position)
	draw_bubbles()

# Retrieve the mesh from a PackedScene, used for dynamically creating a MeshLibrary

func get_mesh(packed_scene):
	var scene_state:SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if(scene_state.get_node_type(i) == "MeshInstance3D"):
			for j in scene_state.get_node_property_count(i):
				var prop_name = scene_state.get_node_property_name(i, j)
				if prop_name == "mesh":
					var prop_value = scene_state.get_node_property_value(i, j)
					
					return prop_value.duplicate()

# Build (place) a structure

func action_build(gridmap_position):
	if Input.is_action_just_pressed("build"):
		
		var previous_tile = gridmap.get_cell_item(gridmap_position)
		
		if previous_tile == -1 and index != 15:
			var hankie = Vector2i(gridmap_position.x, gridmap_position.z)
			bubble_dict[hankie] = "none"
			gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
			map.cash -= structures[index].price
			update_cash()
			print(str(bubble_dict))
		else:
			if previous_tile == 10:
				# INSERT FABRIEK INTERFACE
				print("insert fabriek interface")

# Upgrade a structure

func action_upgrade(gridmap_position):
	if Input.is_action_just_pressed("upgrade"):
		
		var previous_tile = gridmap.get_cell_item(gridmap_position)
		
		if previous_tile == 7 or previous_tile == 8:
			gridmap.set_cell_item(gridmap_position, previous_tile+1, gridmap.get_orthogonal_index_from_basis(selector.basis))
			var honkie = Vector2i(gridmap_position.x, gridmap_position.z)
			bubble_dict[honkie] = "cash"

func draw_bubbles():
	for i in range($"../bubblecontainer".get_child_count()):
		$"../bubblecontainer".get_child(i).queue_free()
	
	for cell in gridmap.get_used_cells():
		var pos2d = Vector2i(cell.x, cell.z)
		if bubble_dict[pos2d] == "cash":
			var camera = $"../View/Camera"
			var pos = Vector3i(cell.x, cell.y, cell.z)
			var screenpos = camera.unproject_position(pos)
			var bubble = bubbles.instantiate()
			$"../bubblecontainer".add_child(bubble)
			bubble.position = screenpos
			bubble.poos = pos2d

# Demolish (remove) a structure

func action_demolish(gridmap_position):
	if Input.is_action_just_pressed("demolish"):
		var structure = gridmap.get_cell_item(gridmap_position)
		if structure != -1:
			map.cash += structures[structure].price/2
			update_cash()
			gridmap.set_cell_item(gridmap_position, -1)
			var henkie = Vector2i(gridmap_position.x, gridmap_position.z)
			bubble_dict[henkie] = "none"

# Rotates the 'cursor' 90 degrees

func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		selector.rotate_y(deg_to_rad(90))

# Toggle between structures to build

func action_structure_toggle():
	if Input.is_action_just_pressed("structure_next"):
		index = wrap(index + 1, 0, structures.size()+1)
	
	if Input.is_action_just_pressed("structure_previous"):
		index = wrap(index - 1, 0, structures.size()+1)

	update_structure()

# Update the structure visual in the 'cursor'

func update_structure():
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		
	# Create new structure preview in selector
	if index != 15:
		var _model = structures[index].model.instantiate()
		selector_container.add_child(_model)
		_model.position.y += 0.25
	
func update_cash():
	cash_display.text = "$" + str(map.cash)


# Saving/load

func action_save():
	if Input.is_action_just_pressed("save") or Global.autoload:

		print("Saving map...")
		
		map.structures.clear()
		for cell in gridmap.get_used_cells():
			
			var data_structure:DataStructure = DataStructure.new()
			
			data_structure.position = Vector2i(cell.x, cell.z)
			data_structure.orientation = gridmap.get_cell_item_orientation(cell)
			data_structure.structure = gridmap.get_cell_item(cell)
			
			map.structures.append(data_structure)
			
		map.bubble_dict = bubble_dict
		ResourceSaver.save(map, "user://map.res")
		Global.autoload = false
	
func action_load():
	if Input.is_action_just_pressed("load") or Global.autoload:
		print("Loading map...")
		
		gridmap.clear()
		
		map = ResourceLoader.load("user://map.res")
		if not map:
			map = DataMap.new()
		for cell in map.structures:
			gridmap.set_cell_item(Vector3i(cell.position.x, 0, cell.position.y), cell.structure, cell.orientation)
		bubble_dict = map.bubble_dict
		
		update_cash()
		Global.autoload = false
		
	
func _on_settings_pressed():
	Global.autoload = true
	action_save()
	Global.autoload = false
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Global.autoload = true
		action_save()
		Global.autoload = false
		get_tree().quit() # default behavior

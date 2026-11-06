extends Node3D
## Individually assembled home structure and cleared furnishings; no prefab scene.
var resting: Dictionary = {}

func rest_at(label: String, player: CharacterBody3D) -> bool:
	if label not in ["BedOne", "BedTwo", "Sofa"] or not is_instance_valid(player) or not player.is_in_group("player") or player.has_meta("home_rest") or player.has_meta("home_ship"): return false
	var furniture = get_node(NodePath(label))
	if player.global_position.distance_to(furniture.global_position) > 3: return false
	var exit = furniture.global_position + Vector3(0, 0.05, 2)
	if not _rest_clear(player, exit): return false
	var target = furniture.global_position + Vector3(0, 0.65, 0)
	if not _rest_clear(player, target, furniture): return false
	resting[player.get_instance_id()] = {"player": weakref(player), "exit": exit, "processing": player.is_physics_processing()}
	var id = player.get_instance_id()
	player.tree_exiting.connect(func(): resting.erase(id), CONNECT_ONE_SHOT)
	player.set_meta("home_rest", weakref(self))
	player.set_physics_process(false)
	preload("res://scripts/worlds/welcome_island/home_contract.gd").reset_player(player, target)
	return true

func _rest_clear(player: CharacterBody3D, point: Vector3, furniture: Node3D = null) -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	var capsule = CapsuleShape3D.new(); capsule.radius = 0.35; capsule.height = 1.9
	query.shape = capsule; query.transform.origin = point + Vector3.UP * 0.96; query.exclude = [player.get_rid()]
	# Resize/crouch geometry belongs to the player. A fixed 1.9 m stand-in
	# can approve a rest destination that intersects a larger avatar's ceiling.
	for collision in player.find_children("*", "CollisionShape3D", true, false):
		if collision.disabled or collision.shape == null: continue
		query.shape = collision.shape
		var relative = player.global_transform.affine_inverse() * collision.global_transform
		query.transform = Transform3D(player.global_basis, point) * relative
		break
	query.collision_mask = player.collision_mask
	if furniture != null:
		var excluded: Array[RID] = [player.get_rid()]
		for body in furniture.find_children("*", "CollisionObject3D", true, false): excluded.append(body.get_rid())
		query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_shape(query).is_empty()

func leave_rest(player: CharacterBody3D) -> bool:
	if not is_instance_valid(player) or not resting.has(player.get_instance_id()): return false
	var record = resting[player.get_instance_id()]
	var target = record.exit if _rest_clear(player, record.exit) else Vector3(0, 1, 0)
	if not _rest_clear(player, target): return false
	player.remove_meta("home_rest"); player.set_physics_process(record.processing)
	preload("res://scripts/worlds/welcome_island/home_contract.gd").reset_player(player, target)
	resting.erase(player.get_instance_id())
	return true

func make_rest_controls() -> VBoxContainer:
	var panel = VBoxContainer.new()
	for label in ["BedOne", "BedTwo", "Sofa", "Leave resting place"]:
		var button = Button.new(); button.text = "Rest nearby: " + label if label != "Leave resting place" else label
		button.custom_minimum_size.y = 44
		button.pressed.connect(func():
			for player in get_tree().get_nodes_in_group("player"):
				if player is CharacterBody3D:
					if label == "Leave resting place": leave_rest(player)
					else: rest_at(label, player))
		panel.add_child(button)
	return panel

func _exit_tree():
	for record in resting.values():
		var player = record.player.get_ref()
		if is_instance_valid(player):
			player.remove_meta("home_rest"); player.set_physics_process(record.processing); player.velocity = Vector3.ZERO
	resting.clear()
func _ready():
	add_to_group("home_resting")
	position = Vector3(24, 0, -20)
	_box("Floor", Vector3(0, -0.08, 0), Vector3(16, 0.2, 14), true)
	_box("BackWall", Vector3(0, 1.7, -7), Vector3(16, 3.4, 0.3), true)
	_box("LeftWall", Vector3(-8, 1.7, 0), Vector3(0.3, 3.4, 14), true)
	_box("RightWall", Vector3(8, 1.7, 0), Vector3(0.3, 3.4, 14), true)
	# Three-metre central doorway, low window sills and upper lintels.
	for side in [-1, 1]:
		_box("FrontSill", Vector3(side * 5, 0.45, 7), Vector3(6, 0.9, 0.3), true)
		_box("FrontLintel", Vector3(side * 5, 3.05, 7), Vector3(6, 0.7, 0.3), true)
	_box("DoorLintel", Vector3(0, 3.05, 7), Vector3(4, 0.7, 0.3), true)
	_box("Roof", Vector3(0, 3.6, 0), Vector3(17, 0.35, 15), true)
	_box("Porch", Vector3(0, -0.06, 8.5), Vector3(10, 0.16, 3), true)
	_install_exterior()
	# Sparse zoning, broad shared circulation; no forced seating/lying head pose.
	_furniture("BedOne", "bedSingle", Vector3(-5, 0, -4.5), Vector3(1.6, 0.7, 2.3))
	_furniture("BedTwo", "bedSingle", Vector3(-2, 0, -4.5), Vector3(1.6, 0.7, 2.3))
	_furniture("Sofa", "loungeSofa", Vector3(-4.5, 0, 2.2), Vector3(3.5, 1, 1.5))
	_furniture("LowTable", "tableCoffee", Vector3(-4.5, 0, 4.2), Vector3(1.8, 0.5, 0.9))
	_furniture("Rug", "rugRectangle", Vector3(-4.5, 0.015, 3.6), Vector3(4.5, 0.02, 3.8), false)
	_furniture("FloorLamp", "lampRoundFloor", Vector3(-6.8, 0, 2), Vector3(0.5, 1.5, 0.5))
	var kitchen = Marker3D.new(); kitchen.name = "KitchenReserve"; kitchen.position = Vector3(5, 0, -3); add_child(kitchen)
	var kitchen_node = preload("res://scripts/worlds/welcome_island/kitchen.gd").new()
	kitchen_node.name = "Kitchen"; add_child(kitchen_node)
	_furniture("HousePlant", "plantSmall1", Vector3(6, 0, 4.8), Vector3(0.5, 0.75, 0.5))
	var lighting = preload("res://scripts/worlds/welcome_island/room_lighting.gd").new()
	lighting.name = "RoomLighting"
	add_child(lighting)

func _furniture(label: String, asset: String, center: Vector3, target: Vector3, solid: bool = true) -> Node3D:
	var root = Node3D.new(); root.name = label; root.position = center; add_child(root)
	var style = {"loungeSofa": "sofa_02", "tableCoffee": "coffee_table_round_01", "bedSingle": "vintage_day_bed", "table": "wooden_picnic_table"}
	var model: Node3D
	if style.has(asset):
		var id: String = style[asset]
		model = load("res://assets/welcome_island/models/style/" + id + "/" + id + "_1k.gltf").instantiate()
		root.set_meta("style_source", "polyhaven." + id)
	else:
		model = load("res://assets/welcome_island/models/furniture/" + asset + ".glb").instantiate()
	root.add_child(model)
	var bounds := AABB(); var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box = model.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box); first = false
	var factor = minf(target.x / maxf(bounds.size.x, 0.01), minf(target.y / maxf(bounds.size.y, 0.01), target.z / maxf(bounds.size.z, 0.01)))
	if asset == "bedSingle":
		# Daybeds include tall upholstery/backrests; size by sleeping footprint,
		# not the old low-poly bed's height, which produced miniature furniture.
		factor = minf(target.x / maxf(bounds.size.x, 0.01), target.z / maxf(bounds.size.z, 0.01))
	model.scale = Vector3.ONE * factor
	model.position = -(bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)) * factor
	if solid:
		var body = StaticBody3D.new(); root.add_child(body)
		var collision = CollisionShape3D.new(); var shape = BoxShape3D.new()
		shape.size = bounds.size * factor; collision.shape = shape; collision.position.y = shape.size.y * 0.5
		body.add_child(collision)
	return root

func _install_exterior():
	var exterior = load("res://assets/welcome_island/models/architecture/bungalow-house.glb").instantiate()
	exterior.name = "AuthoredExterior"
	add_child(exterior)
	exterior.scale = Vector3(1.333333, 1.2, 1.4)
	exterior.position = Vector3(0, -0.384, 0.784)
	# Keep the existing proven collision/circulation. Adapt only the visible front
	# facade to the broad accessible entrance; no closed door or mandatory steps.
	for mesh in exterior.find_children("*", "MeshInstance3D", true, false):
		var label = str(mesh.name).to_lower()
		if "entrance" in label or "stair tread" in label or "service steps" in label or "grounded landing" in label or "foundation and floor" in label or "front left window" in label or "front right window" in label:
			mesh.visible = false
		elif "hollow wall shell" in label:
			var adapted = ArrayMesh.new()
			for surface in mesh.mesh.get_surface_count():
				var arrays = mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var kept = PackedInt32Array()
				for index in range(0, indices.size(), 3):
					var center = (vertices[indices[index]] + vertices[indices[index+1]] + vertices[indices[index+2]]) / 3
					var point = exterior.global_transform.affine_inverse() * mesh.global_transform * center
					if point.z > 4.0 and point.y < 3.0: continue
					kept.append_array(indices.slice(index, index+3))
				if kept.is_empty(): continue
				arrays[Mesh.ARRAY_INDEX] = kept
				adapted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				adapted.surface_set_material(adapted.get_surface_count()-1, mesh.mesh.surface_get_material(surface))
			mesh.mesh = adapted
		for surface in mesh.mesh.get_surface_count():
			var original = mesh.mesh.surface_get_material(surface)
			if original is StandardMaterial3D and "roof tile" in original.resource_name.to_lower():
				var material = original.duplicate()
				material.albedo_color = Color(0.25, 0.29, 0.3)
				material.roughness = 0.85
				mesh.set_surface_override_material(surface, material)
	for name in ["BackWall", "LeftWall", "RightWall"]:
		get_node(NodePath(name)).visible = false
	# The imported shell includes wall details outside its nominal twelve-metre
	# footprint. Fit static side proxies to the aggregate transformed shell,
	# rather than leaving invisible barriers inside the rendered room.
	var shell_nodes = exterior.find_children("*hollow*", "MeshInstance3D", true, false)
	var bounds := AABB(); var first := true
	for mesh in shell_nodes:
		var box = global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box); first = false
	if not first:
		get_node("LeftWall").position.x = bounds.position.x
		get_node("RightWall").position.x = bounds.end.x
	# A timber ceiling separates the liveable rooms from the imported roof void.
	get_node("Roof").mesh.size = Vector3(15.7, 0.2, 13.7)
	get_node("Roof").position.y = 2.95
	get_node("Roof").material_override.albedo_color = Color(0.7, 0.65, 0.55)
	for node in find_children("Front*", "MeshInstance3D", false, false):
		var material = StandardMaterial3D.new(); material.albedo_color = Color(0.73, 0.69, 0.59); material.roughness = 0.85
		node.material_override = material
	var detail_body = StaticBody3D.new()
	detail_body.name = "ArchitecturalDetailCollision"; add_child(detail_body)
	for mesh in exterior.find_children("*", "MeshInstance3D", true, false):
		var label = str(mesh.name).to_lower()
		if not mesh.is_visible_in_tree() or not ("glazing" in label or "frame" in label or "sill" in label or "post" in label or "beam" in label): continue
		# Exact static triangles only for visible, modest architectural details;
		# never use the whole scene, furnishing or vegetation as physics geometry.
		var faces = mesh.mesh.get_faces()
		if faces.is_empty() or faces.size() > 6000: continue
		var transform = global_transform.affine_inverse() * mesh.global_transform
		var detail_bounds = transform * mesh.mesh.get_aabb()
		# The source porch was adapted to a four-metre accessible entry. Details
		# crossing that reviewed corridor are decoration only, not hidden blockers.
		if detail_bounds.position.z > 4 and detail_bounds.position.x < 2.2 and detail_bounds.end.x > -2.2: continue
		for index in faces.size(): faces[index] = transform * faces[index]
		var shape = ConcavePolygonShape3D.new(); shape.set_faces(faces)
		var collision = CollisionShape3D.new(); collision.name = "Detail" + str(detail_body.get_child_count()); collision.shape = shape
		detail_body.add_child(collision)

func _box(label: String, center: Vector3, size: Vector3, solid: bool) -> Node3D:
	var root = MeshInstance3D.new(); root.name = label; root.position = center; add_child(root)
	var mesh = BoxMesh.new(); mesh.size = size; root.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/welcome_island/textures/weathered_planks/weathered_planks_diff_1k.jpg")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/welcome_island/textures/weathered_planks/weathered_planks_nor_gl_1k.jpg")
	material.roughness = 0.85; material.uv1_triplanar = true; material.uv1_world_triplanar = true; material.uv1_scale = Vector3.ONE * 0.5
	root.material_override = material
	if solid:
		var body = StaticBody3D.new(); root.add_child(body)
		var collision = CollisionShape3D.new(); var shape = BoxShape3D.new(); shape.size = size
		collision.shape = shape; body.add_child(collision)
	return root

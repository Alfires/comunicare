extends Node3D
## Original deterministic composition using individual cleared optimized models.
func _ready():
	var trees = Node3D.new(); trees.name = "Trees"; add_child(trees)
	var rocks = Node3D.new(); rocks.name = "Rocks"; add_child(rocks)
	var borders = Node3D.new(); borders.name = "EdgeBorders"; add_child(borders)
	var understory = Node3D.new(); understory.name = "Understory"; add_child(understory)
	var ground_details = Node3D.new(); ground_details.name = "GroundDetails"; add_child(ground_details)
	var scheduler = get_parent().streaming
	var positions = _positions()
	for index in positions.size():
		var species = "fir" if index % 3 != 0 else "pine"
		var variant = ["a", "b", "c"][index % 3]
		var path = "res://assets/welcome_island/models/nature/fir_sapling/fir_sapling_1k.gltf" if species == "fir" else "res://assets/welcome_island/models/runtime/pine_sapling_small_" + variant + ".scn"
		scheduler.enqueue(positions[index], [path], _tree.bind(index, path))
	for index in 160:
		var point = _fern_point(index)
		if absf(point.x) < 3.2 or point.length() > 48: continue
		scheduler.enqueue(point, ["res://assets/welcome_island/models/nature/fern_02/fern_02_1k.gltf"], _fern.bind(index, point))
	for index in 6:
		scheduler.enqueue(positions[index*3], ["res://assets/welcome_island/models/nature/tree_stump_01/tree_stump_01_1k.gltf"], _stump.bind(index))
	for index in 46:
		var point = _rock_point(index)
		scheduler.enqueue(point, ["res://assets/welcome_island/models/runtime/boulder_01.scn"], _rock.bind(index, point))
	_details()
	scheduler.enqueue(Vector3.ZERO, [], _meadow_grass)
	for index in 180:
		var point = _detail_point(index)
		if not _planting_clear(point): continue
		var path = "res://assets/welcome_island/models/runtime/boulder_01.scn" if index % 4 == 0 else "res://assets/welcome_island/models/nature/fern_02/fern_02_1k.gltf"
		scheduler.enqueue(point, [path], _ground_detail.bind(index, point, path))
	for index in 18:
		var point = _detail_point(index*7+3)
		if not _planting_clear(point): continue
		var path = "res://assets/welcome_island/models/runtime/pine_sapling_small_" + ["a", "b", "c"][index%3] + ".scn"
		scheduler.enqueue(point, [path], _young_pine.bind(index, point, path))

func _young_pine(index: int, point: Vector3, path: String):
	var tree = get_parent().streaming.resources[path].instantiate()
	get_node("Trees").add_child(tree); tree.position = point
	tree.scale = Vector3.ONE * (2.5 + (index%4)*0.45)
	tree.rotation.y = index*2.399963; tree.set_meta("species", "pine")
	for mesh in tree.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 85; mesh.lod_bias = 2
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _detail_point(index: int) -> Vector3:
	# Asymmetric islands of growth: open meadow between dense sheltered pockets.
	var centers = [Vector3(-17,0,-16), Vector3(-23,0,-26), Vector3(-35,0,5), Vector3(-13,0,15), Vector3(-17,0,29), Vector3(3,0,-24), Vector3(9,0,12), Vector3(37,0,14), Vector3(30,0,-37)]
	var angle = index * 2.399963
	var radius = 0.8 + sqrt(float((index * 17) % 23) / 23.0) * 5.4
	return centers[index % centers.size()] + Vector3(cos(angle)*radius, 0, sin(angle)*radius*0.7)

func _planting_clear(point: Vector3) -> bool:
	if Vector2(point.x, point.z).length() < 8 or Vector2(point.x, point.z).length() > 47: return false
	if point.x > 13 and point.x < 36 and point.z > -31 and point.z < -8: return false
	if Vector2((point.x-23)/1.15, point.z-23).length() < 16: return false
	for center in [Vector3(-29,0,-12), Vector3(-28,0,19), Vector3(35,0,0)]:
		if absf(point.x-center.x) < 8 and absf(point.z-center.z) < 7: return false
	for route in get_parent().routes.values():
		var previous = Vector3.ZERO
		for endpoint in route:
			if Geometry3D.get_closest_point_to_segment(point, previous, endpoint).distance_to(point) < 3.2: return false
			previous = endpoint
	return true

func _ground_detail(index: int, point: Vector3, path: String):
	var model = get_parent().streaming.resources[path].instantiate()
	get_node("GroundDetails").add_child(model); model.position = point
	model.set_meta("placement", index)
	if index % 4 == 0:
		model.scale = Vector3(0.45 + (index%5)*0.12, 0.28 + (index%3)*0.1, 0.4 + (index%7)*0.08)
		model.rotation = Vector3(sin(index*1.7)*0.4, index*2.399963, cos(index*0.9)*0.3)
	else:
		model.scale = Vector3.ONE * (0.8 + (index%7)*0.13)
		model.rotation = Vector3(sin(index)*0.08, index*2.399963, cos(index)*0.07)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 48
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _meadow_grass():
	# One shared draw for short crossed grass clumps, no extra textures or physics.
	var tool = SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 7:
		var angle = blade * 2.399963
		var base = Vector3(cos(angle), 0, sin(angle)) * 0.11
		var across = Vector3(cos(angle), 0, sin(angle)) * 0.012
		var bend = Vector3(sin(angle), 0, -cos(angle)) * 0.06
		var height = 0.16 + (blade%4)*0.045
		var middle = base + Vector3.UP*height*0.6 + bend*0.3
		var tip = base + Vector3.UP*height + bend
		for point in [base-across, base+across, middle-across*0.6, middle-across*0.6, base+across, middle+across*0.6, middle-across*0.6, middle+across*0.6, tip]:
			tool.add_vertex(point)
	tool.generate_normals()
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.27, 0.36, 0.10)
	material.roughness = 1.0; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = false
	var mesh = tool.commit(); mesh.surface_set_material(0, material)
	var transforms: Array[Transform3D] = []
	for index in 3200:
		var anchor = _detail_point(index % 180)
		var angle = index * 2.399963
		var point = anchor + Vector3(cos(angle),0,sin(angle)) * (0.4 + (index%19)*0.16)
		if not _planting_clear(point): continue
		var basis = Basis(Vector3.UP, angle).scaled(Vector3.ONE * (0.55 + (index%9)*0.09))
		transforms.append(Transform3D(basis, point))
	var instances = MultiMesh.new(); instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh; instances.instance_count = transforms.size()
	for index in transforms.size(): instances.set_instance_transform(index, transforms[index])
	var grass = MultiMeshInstance3D.new(); grass.name = "MeadowGrass"
	grass.multimesh = instances; grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end = 75; add_child(grass)

func _positions() -> Array:
	var positions = [Vector3(-15,0,-30), Vector3(-10,0,-39), Vector3(-5,0,-42), Vector3(5,0,-40), Vector3(13,0,-34), Vector3(-20,0,-35), Vector3(-27,0,-29), Vector3(-35,0,-24), Vector3(-39,0,-18), Vector3(-39,0,-5), Vector3(-40,0,4), Vector3(-35,0,14), Vector3(-33,0,25), Vector3(-26,0,32), Vector3(-16,0,37), Vector3(-6,0,40), Vector3(4,0,38), Vector3(37,0,-17), Vector3(40,0,-9), Vector3(41,0,0), Vector3(40,0,10), Vector3(-15,0,-18), Vector3(-8,0,-26), Vector3(8,0,-32)]
	return positions

func _tree(index: int, path: String):
	var trees = get_node("Trees")
	var positions = _positions()
	# A single placement per scheduler callback, with shared resident resources.
	var variant = ["a", "b", "c"][index % 3]
	var species = "fir" if index % 3 != 0 else "pine"
	var tree: Node3D
	if species == "fir":
		# Preserve authored canopy, but instantiate its source only once.
		var source = _fir_template()
		var selected = source.find_child("fir_sapling_" + variant, true, false)
		tree = selected.duplicate()
		tree.position = Vector3.ZERO
	else:
		tree = get_parent().streaming.resources[path].instantiate()
	tree.set_meta("species", species)
	trees.add_child(tree); tree.position = positions[index]
	tree.scale = Vector3.ONE * ((7.0 + (index % 4) * 0.7) if species == "fir" else (4.5 + (index % 4) * 0.5))
	tree.rotation.y = index * 1.7
	var tree_meshes = tree.find_children("*", "MeshInstance3D", true, false)
	if tree is MeshInstance3D: tree_meshes.append(tree)
	for mesh in tree_meshes:
		mesh.visibility_range_end = 160
		mesh.lod_bias = 8 if species == "fir" else 2
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if index % 4 == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Layer secondary trees behind hero silhouettes instead of an even ring of
	# lone saplings. Keep each destination's center, open spawn and paths clear.
	var original = trees.get_child(trees.get_child_count()-1)
	if index % 3 != 0:
		var point = original.position + Vector3(-2.5 if index % 2 else 2.5, 0, -2)
		if not (point.length() > 47 or absf(point.x) < 4 or (point.x > 15 and point.z > -29 and point.z < -9)):
			var secondary = original.duplicate()
			trees.add_child(secondary); secondary.position = point
			secondary.scale *= 0.65 + (index % 3) * 0.1
			secondary.rotation.y += 1.1
	for placed in trees.get_children():
		if placed.get_node_or_null("Trunk") != null: continue
		var body = StaticBody3D.new(); body.name = "Trunk"; placed.add_child(body)
		var collision = CollisionShape3D.new(); var shape = CylinderShape3D.new()
		shape.radius = 0.06; shape.height = 0.8; collision.shape = shape; collision.position.y = 0.4; body.add_child(collision)

var fir_template: Node3D
func _fir_template() -> Node3D:
	if fir_template == null:
		fir_template = get_parent().streaming.resources["res://assets/welcome_island/models/nature/fir_sapling/fir_sapling_1k.gltf"].instantiate()
	return fir_template

func _exit_tree():
	if is_instance_valid(fir_template): fir_template.free()

func _fern_point(index: int) -> Vector3:
	var cluster: Vector3 = _positions()[index % _positions().size()]
	var angle = index * 2.39996
	return cluster + Vector3(cos(angle), 0, sin(angle)) * (1.1 + index % 4 * 0.5)

func _fern(index: int, point: Vector3):
	var fern = get_parent().streaming.resources["res://assets/welcome_island/models/nature/fern_02/fern_02_1k.gltf"].instantiate()
	get_node("Understory").add_child(fern); fern.position = point; fern.scale = Vector3.ONE * (0.65 + index % 3 * 0.2); fern.rotation.y = index * 2.39996
	for mesh in fern.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 55; mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _stump(index: int):
	var stump = get_parent().streaming.resources["res://assets/welcome_island/models/nature/tree_stump_01/tree_stump_01_1k.gltf"].instantiate()
	get_node("Understory").add_child(stump); stump.position = _positions()[index * 3] + Vector3(2, 0, 1); stump.scale = Vector3.ONE * 0.65

func _rock_point(index: int) -> Vector3:
	if index < 28:
		var angle = index * TAU / 28 + sin(index*2.7)*0.045
		var radius = 47 + sin(index*1.9)*1.3
		return Vector3(cos(angle) * radius, (-0.65 if index % 2 else -3.2) + sin(index*1.3)*0.45, sin(angle) * radius)
	var i = index - 28
	var angle = i * TAU / 18
	return Vector3(cos(angle) * (32 + i % 4), -8 - i % 5, sin(angle) * (32 + i % 4))

func _rock(index: int, point: Vector3):
	var rock = get_parent().streaming.resources["res://assets/welcome_island/models/runtime/boulder_01.scn"].instantiate()
	get_node("Rocks").add_child(rock); rock.position = point
	rock.scale = Vector3(3.7 + index % 3, 2.8 + (index*3 % 5)*0.3, 3.6 + (index*7 % 5)*0.35) if index < 28 else Vector3(6 + sin(index)*1.2, 4.5 + cos(index)*0.8, 6.5 + sin(index*2)*1.1)
	rock.rotation = Vector3(sin(index*1.73)*0.38, index*2.399963, cos(index*2.13)*0.32)
	for mesh in rock.find_children("*", "MeshInstance3D", true, false): mesh.visibility_range_end = 130

func _details():
	var borders = get_node("EdgeBorders")
	for index in 28:
		var angle = index * TAU / 28
		if index % 2 == 0:
			var body = StaticBody3D.new(); borders.add_child(body); body.position = Vector3(cos(angle)*51, 0.4, sin(angle)*51)
			var collision = CollisionShape3D.new(); var shape = BoxShape3D.new(); shape.size = Vector3(3, 1.2, 3)
			collision.shape = shape; body.add_child(collision)
	var roots = Node3D.new(); roots.name = "Roots"; add_child(roots)
	var bark = StandardMaterial3D.new()
	bark.albedo_color = Color(0.22, 0.15, 0.085); bark.roughness = 0.95
	for index in 14:
		var angle = index * TAU / 14 + 0.15
		var start = Vector3(cos(angle)*49, -0.6, sin(angle)*49)
		for branch in 3:
			var end = start + Vector3(cos(angle)*(-0.7-branch*0.2), -2.3-branch*0.8, sin(angle)*(-0.6-branch*0.2))
			var root = MeshInstance3D.new(); roots.add_child(root)
			var mesh = CylinderMesh.new(); mesh.top_radius = 0.22/(branch+1); mesh.bottom_radius = 0.08/(branch+1); mesh.height = start.distance_to(end); mesh.radial_segments = 7
			root.mesh = mesh; root.material_override = bark; root.position = (start+end)*0.5
			root.quaternion = Quaternion(Vector3.UP, (start-end).normalized())
			root.visibility_range_end = 110
			start = end
	var shore = Node3D.new(); shore.name = "ShoreDetails"; add_child(shore)
	for index in 20:
		var angle = index * TAU / 20
		var point = Vector3(23 + cos(angle)*14.8, 0, 23 + sin(angle)*13.2)
		# Keep west dock approach and broad dry perimeter completely clear.
		if point.x < 13 and absf(point.z-23) < 5: continue
		get_parent().streaming.enqueue(point, ["res://assets/welcome_island/models/runtime/boulder_01.scn", "res://assets/welcome_island/models/furniture/plantSmall1.glb"], _shore.bind(index, point, angle))

func _shore(index: int, point: Vector3, angle: float):
	var shore = get_node("ShoreDetails")
	var rock = get_parent().streaming.resources["res://assets/welcome_island/models/runtime/boulder_01.scn"].instantiate()
	shore.add_child(rock); rock.position = point + Vector3(sin(index)*0.3,-0.3-cos(index)*0.1,cos(index)*0.3)
	rock.scale = Vector3(0.5 + (index%3)*0.15, 0.35 + (index%4)*0.09, 0.55 + (index%5)*0.1)
	rock.rotation = Vector3(sin(index*1.3)*0.35, angle + index*1.7, cos(index*1.7)*0.3)
	for mesh in rock.find_children("*", "MeshInstance3D", true, false): mesh.visibility_range_end = 80
	if index%2 == 0:
		var plant = get_parent().streaming.resources["res://assets/welcome_island/models/furniture/plantSmall1.glb"].instantiate()
		shore.add_child(plant); plant.position = point + Vector3(0.4,0,0.3); plant.scale = Vector3.ONE * 1.5

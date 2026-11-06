extends Node3D
## Original deterministic composition using individual cleared optimized models.
func _ready():
	var trees = Node3D.new(); trees.name = "Trees"; add_child(trees)
	var rocks = Node3D.new(); rocks.name = "Rocks"; add_child(rocks)
	var borders = Node3D.new(); borders.name = "EdgeBorders"; add_child(borders)
	var understory = Node3D.new(); understory.name = "Understory"; add_child(understory)
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
		var angle = index * TAU / 28
		return Vector3(cos(angle) * 47, -0.3 if index % 2 else -3, sin(angle) * 47)
	var i = index - 28
	var angle = i * TAU / 18
	return Vector3(cos(angle) * (32 + i % 4), -8 - i % 5, sin(angle) * (32 + i % 4))

func _rock(index: int, point: Vector3):
	var rock = get_parent().streaming.resources["res://assets/welcome_island/models/runtime/boulder_01.scn"].instantiate()
	get_node("Rocks").add_child(rock); rock.position = point
	rock.scale = Vector3(4 + index % 3, 3 + index % 2, 4) if index < 28 else Vector3(7, 5, 7)
	rock.rotation.y = index * TAU / (28 if index < 28 else 18)
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
	shore.add_child(rock); rock.position = point + Vector3(0,-0.3,0); rock.scale = Vector3.ONE * (0.45 + (index%3)*0.15); rock.rotation.y = angle
	for mesh in rock.find_children("*", "MeshInstance3D", true, false): mesh.visibility_range_end = 80
	if index%2 == 0:
		var plant = get_parent().streaming.resources["res://assets/welcome_island/models/furniture/plantSmall1.glb"].instantiate()
		shore.add_child(plant); plant.position = point + Vector3(0.4,0,0.3); plant.scale = Vector3.ONE * 1.5

extends Node3D
## Individually assembled home structure and cleared furnishings; no prefab scene.
func _ready():
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
	# Sparse zoning, broad shared circulation; no forced seating/lying head pose.
	_furniture("BedOne", "bedSingle", Vector3(-5, 0, -4.5), Vector3(1.6, 0.7, 2.3))
	_furniture("BedTwo", "bedSingle", Vector3(-2, 0, -4.5), Vector3(1.6, 0.7, 2.3))
	_furniture("Sofa", "loungeSofa", Vector3(-4.5, 0, 2.2), Vector3(3.5, 1, 1.5))
	_furniture("LowTable", "tableCoffee", Vector3(-4.5, 0, 4.2), Vector3(1.8, 0.5, 0.9))
	_furniture("Rug", "rugRectangle", Vector3(-4.5, 0.015, 3.6), Vector3(4.5, 0.02, 3.8), false)
	_furniture("FloorLamp", "lampRoundFloor", Vector3(-6.8, 0, 2), Vector3(0.5, 1.5, 0.5))
	var kitchen = Marker3D.new(); kitchen.name = "KitchenReserve"; kitchen.position = Vector3(5, 0, -3); add_child(kitchen)
	_box("FutureCounter", Vector3(6.8, 0.45, -3), Vector3(1.1, 0.9, 5), true)
	_furniture("HousePlant", "plantSmall1", Vector3(6, 0, 4.8), Vector3(0.5, 0.75, 0.5))
	# Static warm fill for visibility, not part 10's adjustable room controls.
	var light = OmniLight3D.new(); light.position = Vector3(0, 2.7, 1)
	light.omni_range = 12; light.light_color = Color(1, 0.86, 0.68); light.light_energy = 1.2
	add_child(light)

func _furniture(label: String, asset: String, center: Vector3, target: Vector3, solid: bool = true) -> Node3D:
	var root = Node3D.new(); root.name = label; root.position = center; add_child(root)
	var model = load("res://assets/welcome_island/models/furniture/" + asset + ".glb").instantiate()
	root.add_child(model)
	var bounds := AABB(); var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box = model.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box); first = false
	var factor = minf(target.x / maxf(bounds.size.x, 0.01), minf(target.y / maxf(bounds.size.y, 0.01), target.z / maxf(bounds.size.z, 0.01)))
	model.scale = Vector3.ONE * factor
	model.position = -(bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)) * factor
	if solid:
		var body = StaticBody3D.new(); root.add_child(body)
		var collision = CollisionShape3D.new(); var shape = BoxShape3D.new()
		shape.size = bounds.size * factor; collision.shape = shape; collision.position.y = shape.size.y * 0.5
		body.add_child(collision)
	return root

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

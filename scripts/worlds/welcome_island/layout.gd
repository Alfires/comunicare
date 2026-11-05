extends Node3D
## Original graybox composition. No network, accounts, downloads or tutorial logic.
var routes := {
	"House": [Vector3(0, 0, -10), Vector3(24, 0, -10), Vector3(24, 0, -18)],
	"LeftDeck": [Vector3(-29, 0, 0), Vector3(-29, 0, -12)],
	"RightGarden": [Vector3(35, 0, 0)],
	"Dock": [Vector3(9, 0, 0), Vector3(9, 0, 23)],
	"Grove": [Vector3(0, 0, -33)],
	"Picnic": [Vector3(-24, 0, 0), Vector3(-24, 0, 17)]
}

func _ready():
	_build_land()
	_build_pond()
	# Temporary house walls: open south entrance, no required stairs.
	_box("HouseBack", Vector3(24, 1.6, -27), Vector3(16, 3.2, 0.35), Color(0.53, 0.43, 0.31))
	_box("HouseLeft", Vector3(16, 1.6, -20), Vector3(0.35, 3.2, 14), Color(0.53, 0.43, 0.31))
	_box("HouseRight", Vector3(32, 1.6, -20), Vector3(0.35, 3.2, 14), Color(0.53, 0.43, 0.31))
	_box("DeckFootprint", Vector3(-29, -0.1, -12), Vector3(14, 0.2, 10), Color(0.5, 0.37, 0.24), false)
	_box("GardenFootprint", Vector3(35, -0.08, 0), Vector3(10, 0.16, 12), Color(0.36, 0.4, 0.22), false)
	for name in routes:
		var previous := Vector3.ZERO
		for endpoint in routes[name]:
			var middle: Vector3 = (previous + endpoint) * 0.5
			var distance: float = previous.distance_to(endpoint)
			var path = _box("Path", middle + Vector3(0, 0.015, 0), Vector3(3.6, 0.03, distance + 1), Color(0.64, 0.57, 0.4), false)
			path.rotation.y = atan2(endpoint.x - previous.x, endpoint.z - previous.z)
			previous = endpoint

func _height(x: float, z: float) -> float:
	# Sealed basin; the broad dry west bank connects the dock to the island.
	var distance = Vector2((x - 23) / 1.15, z - 23).length()
	return -2.0 * clampf((13.0 - distance) / 3.0, 0, 1) * clampf((x - 12) / 3, 0, 1)

func _build_pond():
	var water = StaticBody3D.new()
	water.name = "PondWater"
	water.set_meta("teleport_disabled", true)
	water.position = Vector3(23, -0.65, 23)
	add_child(water)
	var visual = MeshInstance3D.new()
	var plane = CylinderMesh.new()
	plane.top_radius = 10.7
	plane.bottom_radius = 10.7
	plane.height = 0.02
	plane.radial_segments = 64
	visual.mesh = plane
	visual.scale.x = 1.15
	var material = _material(Color(0.12, 0.32, 0.36, 1))
	material.roughness = 0.3
	material.metallic = 0.15
	visual.material_override = material
	water.add_child(visual)
	# Trigger-only water: players cannot stand on it, ray queries still see it.
	water.collision_layer = 0
	var trigger = Area3D.new()
	trigger.name = "WaterRecovery"
	trigger.collision_layer = 1
	trigger.collision_mask = 1
	trigger.set_meta("teleport_disabled", true)
	water.add_child(trigger)
	var shape = CollisionShape3D.new()
	var cylinder = CylinderShape3D.new()
	cylinder.radius = 10.7
	cylinder.height = 1.8
	shape.shape = cylinder
	shape.scale.x = 1.15
	shape.position.y = -0.8
	trigger.add_child(shape)
	trigger.body_entered.connect(func(body):
		var world = get_parent()
		if world.has_method("recover_from_pond"): world.recover_from_pond(body))
	var deck = _box("DockDeck", Vector3(12.5, -0.15, 23), Vector3(9, 0.3, 3.6), Color.WHITE)
	deck.material_override = _surface_material("weathered_planks", 2)
	for index in 25:
		var plank = _box("DockPlank", Vector3(8.18 + index * 0.36, 0.025, 23), Vector3(0.34, 0.05, 3.6), Color.WHITE, false)
		plank.material_override = _surface_material("weathered_planks", 2)
	for x in [9, 12, 16]:
		for z in [21.5, 24.5]:
			var post = _box("DockPost", Vector3(x, -1.05, z), Vector3(0.22, 2.1, 0.22), Color.WHITE)
			post.material_override = _surface_material("weathered_planks", 2)

func _build_land():
	var land = get_node("Landmass")
	var body = StaticBody3D.new()
	body.name = "ContinuousTerrain"
	land.add_child(body)
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := 52
	var edges := {}
	# Shared-height grid: no gaps between faces, central plateau at y=0.
	for x in range(-radius, radius, 2):
		for z in range(-radius, radius, 2):
			if Vector2(x + 1, z + 1).length() > radius: continue
			var a = Vector3(x, _height(x, z), z)
			var b = Vector3(x + 2, _height(x + 2, z), z)
			var c = Vector3(x, _height(x, z + 2), z + 2)
			var d = Vector3(x + 2, _height(x + 2, z + 2), z + 2)
			for point in [a, b, c, b, d, c]: tool.add_vertex(point)
			for edge in [[a, b], [b, d], [d, c], [c, a]]:
				var key = str(edge[0]) + str(edge[1])
				var reverse = str(edge[1]) + str(edge[0])
				if edges.has(reverse): edges.erase(reverse)
				else: edges[key] = edge
	for edge in edges.values():
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		var c = Vector3(a.x, -4, a.z)
		var d = Vector3(b.x, -4, b.z)
		for point in [a, c, b, b, c, d]: tool.add_vertex(point)
	tool.generate_normals()
	var mesh = tool.commit()
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _surface_material("sparse_grass", 2.5)
	body.add_child(instance)
	var collision = CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	# Continuous tapered underside, not separate playable islands.
	var underside = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 52
	cone.bottom_radius = 12
	cone.height = 24
	cone.radial_segments = 15
	underside.mesh = cone
	underside.position.y = -16
	underside.material_override = _surface_material("rock_01", 4.0)
	add_child(underside)

func _material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _surface_material(id: String, meters: float) -> StandardMaterial3D:
	var material = _material(Color.WHITE)
	var prefix = "res://assets/welcome_island/textures/" + id + "/" + id
	material.albedo_texture = load(prefix + "_diff_1k.jpg")
	material.normal_enabled = true
	material.normal_texture = load(prefix + "_nor_gl_1k.jpg")
	material.roughness_texture = load(prefix + "_rough_1k.jpg")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / meters
	return material

func _box(label: String, center: Vector3, size: Vector3, color: Color, solid: bool = true) -> Node3D:
	var node = MeshInstance3D.new()
	node.name = label
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	if label == "Path": node.material_override = _surface_material("rock_path", 2.0)
	elif label in ["HouseBack", "HouseLeft", "HouseRight", "DeckFootprint", "DockFootprint", "DockDeck", "DockPost"]:
		node.material_override = _surface_material("weathered_planks", 2.0)
	node.position = center
	add_child(node)
	if solid:
		var body = StaticBody3D.new()
		node.add_child(body)
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
	return node

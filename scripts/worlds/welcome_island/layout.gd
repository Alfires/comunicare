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

var streaming: Node
var streaming_materials := false
signal home_ready
var home_loaded := false

func _ready():
	streaming = preload("res://scripts/worlds/welcome_island/streaming.gd").new()
	streaming.name = "Streaming"; add_child(streaming)
	_build_land()
	_build_pond()
	var landscape = preload("res://scripts/worlds/welcome_island/landscape.gd").new()
	landscape.name = "Landscape"; add_child(landscape)
	var paths: Array = []
	_collect_visual_paths("res://assets/welcome_island/models/architecture", paths)
	_collect_visual_paths("res://assets/welcome_island/models/style", paths)
	_collect_visual_paths("res://assets/welcome_island/models/furniture", paths)
	_collect_visual_paths("res://assets/welcome_island/models/kitchenware", paths)
	_collect_visual_paths("res://assets/welcome_island/models/ship", paths)
	_collect_visual_paths("res://assets/welcome_island/textures/weathered_planks", paths)
	streaming.enqueue(Vector3(24, 0, -20), paths, _build_home)
	var textures: Array = []
	_collect_visual_paths("res://assets/welcome_island/textures", textures)
	streaming.enqueue(Vector3.ZERO, textures, _upgrade_materials)

func _collect_visual_paths(folder: String, paths: Array):
	for file in DirAccess.get_files_at(folder):
		# Exported PCKs expose remap/import sidecars instead of source payloads.
		var source = file.trim_suffix(".remap").trim_suffix(".import")
		if source.get_extension() in ["gltf", "glb", "jpg"]:
			# Model imports own their dependent textures. Do not race a separate
			# top-level texture request against the model's dependency loader.
			if "/models/" in folder and source.get_extension() == "jpg": continue
			var path = folder.path_join(source)
			if not paths.has(path): paths.append(path)
	for child in DirAccess.get_directories_at(folder): _collect_visual_paths(folder.path_join(child), paths)

func _upgrade_materials():
	streaming_materials = true
	var meadow = get_node("Landmass/ContinuousTerrain").get_child(0).material_override
	var prefix = "res://assets/welcome_island/textures/sparse_grass/sparse_grass_"
	for entry in [["ground_color", "diff"], ["ground_normal", "nor_gl"], ["ground_roughness", "rough"]]:
		meadow.set_shader_parameter(entry[0], streaming.resources[prefix + entry[1] + "_1k.jpg"])
	meadow.set_shader_parameter("textures_ready", true)
	for node in find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("home_surface"):
			var spec = node.get_meta("home_surface")
			node.material_override = _surface_material(spec[0], spec[1])

func _build_home():
	# Dependencies are already resident before this main-thread assembly.
	var house = preload("res://scripts/worlds/welcome_island/house_spaces.gd").new()
	house.name = "House"; add_child(house)
	if not house.furnished_ready: await house.furnished
	if not is_inside_tree() or is_queued_for_deletion(): return
	_box("DeckFootprint", Vector3(-29, -0.08, -12), Vector3(14, 0.2, 10), Color(0.5, 0.37, 0.24), false)
	_box("GardenFootprint", Vector3(35, -0.08, 0), Vector3(10, 0.16, 12), Color(0.36, 0.4, 0.22), false)
	house._furniture("LeftBench", "bench", Vector3.ZERO, Vector3(2.4, 1, 1))
	var bench = house.get_node("LeftBench"); bench.reparent(self); bench.position = Vector3(-32, 0, -15)
	var cushions = house._furniture("LeftCushions", "benchCushionLow", Vector3.ZERO, Vector3(2, 0.5, 0.8)); cushions.reparent(self); cushions.position = Vector3(-26, 0, -15)
	var picnic = house._furniture("PicnicTable", "table", Vector3.ZERO, Vector3(3, 0.85, 1.6)); picnic.reparent(self); picnic.position = Vector3(-28, 0, 19)
	var shore = house._furniture("ShoreBench", "bench", Vector3.ZERO, Vector3(2.4, 1, 1)); shore.reparent(self); shore.position = Vector3(35, 0, 5)
	_box("HerbBedOne", Vector3(38, 0.2, -3), Vector3(2, 0.4, 3), Color(0.25, 0.2, 0.12))
	_box("HerbBedTwo", Vector3(32, 0.2, -3), Vector3(2, 0.4, 3), Color(0.25, 0.2, 0.12))
	for index in 6:
		var plant = house._furniture("Herbs", "plantSmall1", Vector3.ZERO, Vector3(0.4, 0.5, 0.4), false)
		plant.reparent(self); plant.position = Vector3(32 if index < 3 else 38, 0.4, -4 + index % 3)
	for name in routes:
		var previous := Vector3.ZERO
		for endpoint in routes[name]:
			var middle: Vector3 = (previous + endpoint) * 0.5
			var distance: float = previous.distance_to(endpoint)
			var path = _box("Path", middle + Vector3(0, 0.015, 0), Vector3(2.8, 0.03, distance + 1), Color(0.64, 0.57, 0.4), false)
			path.rotation.y = atan2(endpoint.x - previous.x, endpoint.z - previous.z)
			# Break the ruler-straight graybox strip with low, irregular grass
			# shoulders. Visual-only edges never introduce a walking obstacle.
			var shoulder = MeshInstance3D.new()
			var ribbon = SurfaceTool.new(); ribbon.begin(Mesh.PRIMITIVE_TRIANGLES)
			var direction: Vector3 = (endpoint - previous).normalized()
			var side = direction.cross(Vector3.UP)
			for section in range(ceili(distance / 2)):
				var a = previous + direction * minf(section * 2, distance)
				var b = previous + direction * minf((section+1)*2, distance)
				var width_a = 1.6 + sin(section * 1.7) * 0.22
				var width_b = 1.6 + sin((section+1)*1.7) * 0.22
				for sign_value in [-1, 1]:
					for point in [a+side*sign_value*1.12, a+side*sign_value*width_a, b+side*sign_value*1.12, b+side*sign_value*1.12, a+side*sign_value*width_a, b+side*sign_value*width_b]:
						ribbon.add_vertex(point + Vector3.UP*0.035)
			ribbon.generate_normals(); shoulder.mesh = ribbon.commit()
			shoulder.material_override = get_node("Landmass/ContinuousTerrain").get_child(0).material_override
			add_child(shoulder)
			previous = endpoint
	home_loaded = true
	home_ready.emit()

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
	visual.name = "Surface"
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Single upper surface without an exposed dark cylinder rim. Follow the same
	# basin height function so the water never hangs above the west bank.
	var boundary: Array[Vector3] = []
	for index in 96:
		var direction = Vector2(cos(index * TAU / 96), sin(index * TAU / 96))
		var low := 0.0
		var high := 14.0
		for iteration in 16:
			var distance = (low + high) * 0.5
			var point = Vector2(23, 23) + direction * Vector2(1.15, 1) * distance
			if _height(point.x, point.y) < -0.65: low = distance
			else: high = distance
		boundary.append(Vector3(direction.x * 1.15 * low, 0, direction.y * low))
	for index in boundary.size():
		for point in [Vector3.ZERO, boundary[index], boundary[(index + 1) % boundary.size()]]:
			surface.add_vertex(point)
	surface.generate_normals()
	visual.mesh = surface.commit()
	var material = ShaderMaterial.new()
	material.shader = load("res://scenes/worlds/welcome_island/pond_water.gdshader")
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
		plank.set_meta("home_surface", ["weathered_planks", 2.0])
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
			var angle = atan2(z + 1, x + 1)
			var outline = radius + 1.0 + sin(angle * 3) * 0.6 + sin(angle * 7) * 0.4
			if Vector2(x + 1, z + 1).length() > outline: continue
			var a = Vector3(x, _height(x, z), z)
			var b = Vector3(x + 2, _height(x + 2, z), z)
			var c = Vector3(x, _height(x, z + 2), z + 2)
			var d = Vector3(x + 2, _height(x + 2, z + 2), z + 2)
			# Move only the outer rim onto its smooth radial contour. Interior grid,
			# spawn and all tested routes stay unchanged; the silhouette loses its
			# staircase of alternating two-metre cliff teeth.
			a = _rim_point(a)
			b = _rim_point(b)
			c = _rim_point(c)
			d = _rim_point(d)
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
	var meadow = ShaderMaterial.new()
	meadow.shader = load("res://scenes/worlds/welcome_island/meadow.gdshader")
	instance.material_override = meadow
	body.add_child(instance)
	var collision = CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	# Deterministic irregular rock strata; no flat-ended primitive cone.
	var underside = MeshInstance3D.new()
	underside.name = "RockUnderside"
	var rock = SurfaceTool.new(); rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for layer in 6:
		var ring: Array[Vector3] = []
		for index in 64:
			var angle = index * TAU / 64
			var radius_at_layer = [52.3, 49.0, 40.0, 30.0, 16.0, 2.0][layer]
			var variation = sin(angle * 5 + layer * 0.8) * (1.0 + layer * 0.3) + cos(angle * 9 - layer) * 0.8
			var radius_value = maxf(0.8, radius_at_layer + variation)
			var y = [-3.8, -7.0, -12.0, -18.0, -24.0, -28.0][layer] + sin(angle * 4 + layer) * (0.3 + layer * 0.25)
			ring.append(Vector3(cos(angle) * radius_value, y, sin(angle) * radius_value))
		rings.append(ring)
	for layer in 5:
		for index in 64:
			var next = (index + 1) % 64
			for point in [rings[layer][index], rings[layer+1][index], rings[layer][next], rings[layer][next], rings[layer+1][index], rings[layer+1][next]]:
				rock.add_vertex(point)
	for index in 64:
		for point in [rings[5][index], Vector3(0, -29, 0), rings[5][(index+1)%64]]: rock.add_vertex(point)
	rock.generate_normals()
	underside.mesh = rock.commit()
	underside.material_override = _surface_material("rock_01", 4.0)
	underside.set_meta("home_surface", ["rock_01", 4.0])
	add_child(underside)

func _rim_point(point: Vector3) -> Vector3:
	var flat = Vector2(point.x, point.z)
	if flat.length() < 49: return point
	var angle = atan2(point.z, point.x)
	var radius = 52.5 + sin(angle * 3) * 0.8 + sin(angle * 7) * 0.5
	flat = flat.normalized() * radius
	return Vector3(flat.x, point.y, flat.y)

func _material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _surface_material(id: String, meters: float) -> StandardMaterial3D:
	var material = _material(Color.WHITE)
	if not streaming_materials:
		material.albedo_color = Color(0.32, 0.38, 0.23) if id == "sparse_grass" else Color(0.42, 0.35, 0.26)
		return material
	var prefix = "res://assets/welcome_island/textures/" + id + "/" + id
	material.albedo_texture = load(prefix + "_diff_1k.jpg")
	if id == "rock_path": material.albedo_color = Color(0.72, 0.66, 0.53)
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
	if label == "Path":
		node.material_override = _surface_material("rock_path", 2.0)
		node.set_meta("home_surface", ["rock_path", 2.0])
	elif label in ["HouseBack", "HouseLeft", "HouseRight", "DeckFootprint", "DockFootprint", "DockDeck", "DockPost"]:
		node.material_override = _surface_material("weathered_planks", 2.0)
		node.set_meta("home_surface", ["weathered_planks", 2.0])
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

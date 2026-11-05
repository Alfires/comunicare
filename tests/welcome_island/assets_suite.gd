extends SceneTree
## Import/inspection contracts only; no startup/autoloads/capture/network.
var passed := 0
var failed := 0

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func run():
	for name in ["pine_sapling_small_a", "pine_sapling_small_b", "pine_sapling_small_c", "boulder_01"]:
		var runtime_path = "res://assets/welcome_island/models/runtime/" + name + ".scn"
		check(ResourceLoader.exists(runtime_path), "optimized runtime scene exists: " + name)
		if not ResourceLoader.exists(runtime_path): continue
		var scene = load(runtime_path).instantiate()
		var triangles := 0
		var vertices := 0
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			var lod_check = ImporterMesh.from_mesh(node.mesh)
			var lods := 0
			for surface in node.mesh.get_surface_count():
				var arrays = node.mesh.surface_get_arrays(surface)
				triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
				vertices += arrays[Mesh.ARRAY_VERTEX].size()
				check(arrays[Mesh.ARRAY_NORMAL] != null and arrays[Mesh.ARRAY_NORMAL].size() == arrays[Mesh.ARRAY_VERTEX].size(), "optimized normals retained: " + name)
				check(node.mesh.surface_get_material(surface) is BaseMaterial3D, "optimized material retained: " + name)
				lods += lod_check.get_surface_lod_count(surface)
			check(lods > 0, "optimized mesh includes lower distance LODs: " + name)
		check(triangles > 0 and triangles <= 16000, "runtime model stays within 16K triangle budget: " + name)
		check(vertices <= triangles * 3, "runtime mesh compacts unused vertices: " + name)
		print("OPTIMIZED: ", name, " triangles=", triangles, " vertices=", vertices)
		scene.free()
	var path = "res://assets/welcome_island/manifest.json"
	check(FileAccess.file_exists(path), "bundled asset manifest exists")
	if not FileAccess.file_exists(path):
		finish(); return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	for id in ["sparse_grass", "rock_path", "rock_01", "weathered_planks"]:
		var matches = data.assets.filter(func(entry): return entry.id == "polyhaven." + id)
		check(matches.size() == 1, "realistic surface palette exists: " + id)
		if matches.size() == 1:
			check(matches[0].files.size() == 3, "surface has diffuse/OpenGL normal/roughness maps: " + id)
	for entry in data.assets:
		for file in entry.files:
			var resource_path = "res://" + file.path
			if file.path.ends_with(".gltf"):
				var packed = load(resource_path)
				check(packed is PackedScene, entry.id + " imports as a scene")
				if not packed is PackedScene: continue
				var scene = packed.instantiate()
				var meshes = scene.find_children("*", "MeshInstance3D", true, false)
				check(not meshes.is_empty(), entry.id + " has mesh geometry")
				var vertices := 0
				var triangles := 0
				var bounds := AABB()
				var first := true
				for node in meshes:
					var box = node.transform * node.mesh.get_aabb()
					bounds = box if first else bounds.merge(box)
					first = false
					for surface in node.mesh.get_surface_count():
						var arrays = node.mesh.surface_get_arrays(surface)
						vertices += arrays[Mesh.ARRAY_VERTEX].size()
						check(arrays[Mesh.ARRAY_NORMAL] != null and arrays[Mesh.ARRAY_NORMAL].size() == arrays[Mesh.ARRAY_VERTEX].size(), entry.id + " has vertex normals")
						if arrays[Mesh.ARRAY_INDEX] != null: triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
						var material = node.mesh.surface_get_material(surface)
						check(material is BaseMaterial3D, entry.id + " has imported PBR material")
						if material is BaseMaterial3D and material.resource_name.contains("twig"):
							check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
								entry.id + " foliage uses alpha cutout rather than opaque cards")
							check(material.cull_mode == BaseMaterial3D.CULL_DISABLED, entry.id + " foliage is double-sided")
				check(vertices > 0 and bounds.size.is_finite() and bounds.size.length() > 0.01 and bounds.size.length() < 100,
					entry.id + " has plausible finite meter-scale bounds")
				print("INSPECT: ", entry.id, " bounds=", bounds.size, " vertices=", vertices, " triangles=", triangles)
				scene.free()
			elif file.path.ends_with(".jpg") or file.path.ends_with(".hdr"):
				var texture = load(resource_path)
				check(texture is Texture2D and texture.get_width() <= 2048 and texture.get_height() <= 2048,
					file.original_name + " imports within 2K texture budget")
	if OS.get_environment("WELCOME_ASSET_RENDERED") == "1":
		await preview()
	finish()

func preview():
	var world = Node3D.new()
	root.add_child(world)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var panorama = PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/welcome_island/sky/kloofendal_48d_partly_cloudy_puresky/kloofendal_48d_partly_cloudy_puresky_1k.hdr")
	sky.sky_material = panorama
	environment.environment.sky = sky
	world.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	world.add_child(light)
	var tree = load("res://assets/welcome_island/models/runtime/pine_sapling_small_a.scn").instantiate()
	world.add_child(tree)
	tree.position.x = -2
	var original_tree = load("res://assets/welcome_island/models/pine_sapling_small/pine_sapling_small_1k.gltf").instantiate()
	world.add_child(original_tree)
	original_tree.position = Vector3(-2, 0, -3)
	var rock = load("res://assets/welcome_island/models/runtime/boulder_01.scn").instantiate()
	world.add_child(rock)
	rock.position.x = 2
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var material = StandardMaterial3D.new()
	var prefix = "res://assets/welcome_island/textures/forest_floor/forest_floor_"
	material.albedo_texture = load(prefix + "diff_1k.jpg")
	material.normal_enabled = true
	material.normal_texture = load(prefix + "nor_gl_1k.jpg")
	material.roughness_texture = load(prefix + "rough_1k.jpg")
	material.uv1_scale = Vector3(4, 4, 4)
	floor_mesh.material_override = material
	world.add_child(floor_mesh)
	var camera = Camera3D.new()
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 3, 7), Vector3(0, 0.6, 0))
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("/tmp/opencode/welcome-assets.png") == OK,
		"rendered inspection screenshot saved outside repository")
	world.queue_free()
	await process_frame

func finish():
	print("Welcome assets: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

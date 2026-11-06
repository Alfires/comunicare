extends SceneTree
## Offline Godot 4.7 meshoptimizer LOD reduction; never runs in game startup.
func _initialize(): call_deferred("run")

func run():
	DirAccess.make_dir_recursive_absolute("res://assets/welcome_island/models/runtime")
	for id in ["pine_sapling_small", "boulder_01"]:
		var source = load("res://assets/welcome_island/models/" + id + "/" + id + "_1k.gltf").instantiate()
		for node in source.find_children("*", "MeshInstance3D", true, false):
			var reduced = ArrayMesh.new()
			for surface in node.mesh.get_surface_count():
				var arrays = node.mesh.surface_get_arrays(surface)
				var importer = ImporterMesh.new()
				importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
				importer.generate_lods(60, 60, [])
				var chosen = arrays[Mesh.ARRAY_INDEX]
				for lod in importer.get_surface_lod_count(0):
					var indices = importer.get_surface_lod_indices(0, lod)
					if indices.size() <= 7000 * 3:
						chosen = indices
						break
				# Compact every per-vertex channel using the selected topology.
				var old_count = arrays[Mesh.ARRAY_VERTEX].size()
				var remap := {}
				var order: Array[int] = []
				var indices = PackedInt32Array()
				for old in chosen:
					if not remap.has(old):
						remap[old] = order.size()
						order.append(old)
					indices.append(remap[old])
				for channel in Mesh.ARRAY_MAX:
					if channel == Mesh.ARRAY_INDEX or arrays[channel] == null or arrays[channel].is_empty(): continue
					var stride: int = arrays[channel].size() / old_count
					var compact = arrays[channel].duplicate()
					compact.clear()
					for old in order:
						for component in stride: compact.append(arrays[channel][old * stride + component])
					arrays[channel] = compact
				arrays[Mesh.ARRAY_INDEX] = indices
				reduced.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				reduced.surface_set_material(surface, node.mesh.surface_get_material(surface))
			# Generate lower distance LODs on the already-reduced base mesh.
			var final_importer = ImporterMesh.from_mesh(reduced)
			final_importer.generate_lods(60, 60, [])
			var model = Node3D.new()
			model.name = node.name
			var mesh = MeshInstance3D.new()
			mesh.name = "Model"
			mesh.mesh = final_importer.get_mesh()
			model.add_child(mesh)
			mesh.owner = model
			var packed = PackedScene.new()
			packed.pack(model)
			var path = "res://assets/welcome_island/models/runtime/" + str(node.name) + ".scn"
			if ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) != OK:
				quit(1); return
			print("Reduced: ", path)
			model.free()
		source.free()
	quit()

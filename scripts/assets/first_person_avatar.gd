extends RefCounted
## Separate head triangles onto a camera-exclusive layer, not global visibility.
const HEAD_LAYER = 1 << 19

static func apply(avatar: Node3D, camera: Camera3D) -> bool:
	camera.cull_mask &= ~HEAD_LAYER
	var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
	var rig: Skeleton3D = reader._skeleton(avatar)
	var mapping: Dictionary = avatar.get_meta("humanoid_bones", {})
	if rig == null or not mapping.has("head"): return false
	var head = rig.find_bone(mapping.head)
	if head < 0: return false
	var head_bones: Dictionary = {}
	for index in rig.get_bone_count():
		var parent = index
		while parent >= 0:
			if parent == head:
				head_bones[index] = true
				break
			parent = rig.get_bone_parent(parent)
	var changed := false
	for node in avatar.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("first_person_split") or node.mesh == null: continue
		var mesh: Mesh = node.mesh
		var body_mesh = ArrayMesh.new()
		var head_mesh = ArrayMesh.new()
		for target in [body_mesh, head_mesh]:
			target.blend_shape_mode = mesh.blend_shape_mode
			for i in mesh.get_blend_shape_count(): target.add_blend_shape(mesh.get_blend_shape_name(i))
		var split := false
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var head_vertices: Dictionary = {}
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones != null and weights != null and not vertices.is_empty() and node.skin != null:
				var influences = bones.size() / vertices.size()
				for vertex in vertices.size():
					for influence in int(influences):
						var offset = vertex * int(influences) + influence
						if weights[offset] <= 0.01: continue
						var bind = bones[offset]
						if bind >= node.skin.get_bind_count(): continue
						var name = node.skin.get_bind_name(bind)
						var bone = rig.find_bone(name) if name != &"" else node.skin.get_bind_bone(bind)
						if head_bones.has(bone): head_vertices[vertex] = true
			elif node.name.to_lower().contains("head") or node.name.to_lower().contains("hair") or node.name.to_lower().contains("face"):
				for vertex in vertices.size(): head_vertices[vertex] = true
			var indices = arrays[Mesh.ARRAY_INDEX]
			if indices == null or indices.is_empty():
				indices = PackedInt32Array(range(vertices.size()))
			var body_indices = PackedInt32Array()
			var head_indices = PackedInt32Array()
			if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: return false
			for triangle in range(0, indices.size() - 2, 3):
				var is_head = head_vertices.has(indices[triangle]) or head_vertices.has(indices[triangle + 1]) or head_vertices.has(indices[triangle + 2])
				var destination = head_indices if is_head else body_indices
				destination.append_array(indices.slice(triangle, triangle + 3))
			var blends = mesh.surface_get_blend_shape_arrays(surface)
			for pair in [[body_mesh, body_indices], [head_mesh, head_indices]]:
				if pair[1].is_empty(): continue
				var output = arrays.duplicate()
				output[Mesh.ARRAY_INDEX] = pair[1]
				pair[0].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output, blends)
				var material = node.get_surface_override_material(surface)
				pair[0].surface_set_material(pair[0].get_surface_count() - 1, material if material != null else mesh.surface_get_material(surface))
			if not head_indices.is_empty(): split = true
		if not split: continue
		var original_layers: int = node.layers
		var duplicate = node.duplicate(0) as MeshInstance3D
		duplicate.name = str(node.name) + "_OtherCamerasHead"
		duplicate.mesh = head_mesh
		duplicate.layers = HEAD_LAYER
		duplicate.set_meta("first_person_split", true)
		# Keep the same skeleton path and transform by adding a sibling.
		node.get_parent().add_child(duplicate)
		duplicate.transform = node.transform
		node.set_meta("first_person_split", true)
		if body_mesh.get_surface_count() > 0: node.mesh = body_mesh
		else: node.layers = HEAD_LAYER
		if body_mesh.get_surface_count() == 0:
			duplicate.queue_free() # Original is already head-only; no duplicate needed.
		else:
			node.layers = original_layers & ~HEAD_LAYER
			var sync = BlendShapeSync.new()
			sync.source = node
			sync.target = duplicate
			node.add_child(sync)
		changed = true
	return changed

class BlendShapeSync extends Node:
	var source: MeshInstance3D
	var target: MeshInstance3D
	func _process(_delta: float):
		if not is_instance_valid(source) or not is_instance_valid(target): return
		for index in mini(source.get_blend_shape_count(), target.get_blend_shape_count()):
			target.set_blend_shape_value(index, source.get_blend_shape_value(index))

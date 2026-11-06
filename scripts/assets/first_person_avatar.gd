extends RefCounted
## Prepare a first-person derivative without ever replacing the original mesh.
const HEAD_LAYER = 1 << 19
const BODY_LAYER = 1 << 18

static func is_camera_interior_bone(role: String) -> bool:
	return role in ["neck", "head", "leftEye", "rightEye", "jaw"]

static func apply(avatar: Node3D, camera: Camera3D) -> bool:
	if not avatar.get_meta("first_person_prepared", false): return false
	camera.set_meta("first_person_camera", true)
	camera.cull_mask &= ~HEAD_LAYER
	camera.cull_mask |= BODY_LAYER
	for node in avatar.find_children("*", "MeshInstance3D", true, false):
		if node.get_meta("first_person_original", false):
			node.layers = 0 if node.get_meta("first_person_only", false) else HEAD_LAYER
		elif node.get_meta("first_person_derivative", false):
			node.layers = BODY_LAYER
			node.set_meta("first_person_active", true)
			var source = node.get_meta("first_person_source").get_ref()
			node.visible = is_instance_valid(source) and source.visible
	return true

static func configure_camera(node: Node):
	if node is Camera3D and not node.get_meta("first_person_camera", false):
		node.cull_mask &= ~BODY_LAYER

static func prepare(avatar: Node3D, annotations: Dictionary = {}) -> bool:
	if avatar.get_meta("first_person_prepared", false): return true
	var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
	var rig: Skeleton3D = reader._skeleton(avatar)
	var mapping: Dictionary = avatar.get_meta("humanoid_bones", {})
	if rig == null or not mapping.has("head"): return false
	var head = rig.find_bone(mapping.head)
	if head < 0: return false
	var head_bones: Dictionary = {}
	for role in mapping:
		if is_camera_interior_bone(role):
			var index = rig.find_bone(mapping[role])
			if index >= 0: head_bones[index] = true
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
		var visibility: String = annotations.get(str(node.name), "auto")
		# Even author-marked Both meshes need local head filtering. Keep the
		# original intact and preserve torso/limbs in the local derivative.
		if visibility == "thirdPersonOnly":
			node.set_meta("first_person_original", true)
			continue
		if visibility == "firstPersonOnly":
			node.set_meta("first_person_only", true)
			node.layers = 0
		var body_mesh = ArrayMesh.new()
		for target in [body_mesh]:
			if mesh is ArrayMesh:
				target.blend_shape_mode = mesh.blend_shape_mode
				for i in mesh.get_blend_shape_count(): target.add_blend_shape(mesh.get_blend_shape_name(i))
		var split := false
		var source_surfaces: Array[int] = []
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var head_vertices: Dictionary = {}
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones != null and weights != null and not vertices.is_empty() and node.skin != null:
				var influences = bones.size() / vertices.size()
				for vertex in vertices.size():
					var head_weight := 0.0
					for influence in int(influences):
						var offset = vertex * int(influences) + influence
						if weights[offset] <= 0.01: continue
						var bind = bones[offset]
						if bind >= node.skin.get_bind_count(): continue
						var name = node.skin.get_bind_name(bind)
						var bone = rig.find_bone(name) if name != &"" else node.skin.get_bind_bone(bind)
						if head_bones.has(bone): head_weight += weights[offset]
					if head_weight >= 0.25: head_vertices[vertex] = true
			elif node.name.to_lower().contains("head") or node.name.to_lower().contains("hair") or node.name.to_lower().contains("face"):
				for vertex in vertices.size(): head_vertices[vertex] = true
			var indices = arrays[Mesh.ARRAY_INDEX]
			if indices == null or indices.is_empty():
				indices = PackedInt32Array(range(vertices.size()))
			var body_indices = PackedInt32Array()
			var head_indices = PackedInt32Array()
			if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: return false
			for triangle in range(0, indices.size() - 2, 3):
				var is_head = head_vertices.has(indices[triangle]) or head_vertices.has(indices[triangle + 1]) or head_vertices.has(indices[triangle + 2])
				var destination = head_indices if is_head else body_indices
				destination.append_array(indices.slice(triangle, triangle + 3))
			var blends = mesh.surface_get_blend_shape_arrays(surface) if mesh is ArrayMesh else []
			for pair in [[body_mesh, body_indices]]:
				if pair[1].is_empty(): continue
				var output = arrays.duplicate()
				output[Mesh.ARRAY_INDEX] = pair[1]
				pair[0].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output, blends)
				pair[0].surface_set_material(pair[0].get_surface_count() - 1, mesh.surface_get_material(surface))
				source_surfaces.append(surface)
			if not head_indices.is_empty(): split = true
		# Keep every original surface, skin, material and expression track intact.
		# Only the optional local-view derivative uses filtered triangle indices.
		if body_mesh.get_surface_count() == 0:
			node.set_meta("first_person_original", true)
			continue
		var duplicate = MeshInstance3D.new()
		duplicate.name = str(node.name) + "_FirstPerson"
		duplicate.mesh = body_mesh if split else mesh
		duplicate.skin = node.skin
		duplicate.skeleton = node.skeleton
		duplicate.material_override = node.material_override
		duplicate.transparency = node.transparency
		for surface in source_surfaces.size():
			duplicate.set_surface_override_material(surface, node.get_surface_override_material(source_surfaces[surface]))
		duplicate.custom_aabb = node.custom_aabb
		duplicate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		duplicate.layers = BODY_LAYER
		duplicate.visible = false
		duplicate.set_meta("first_person_derivative", true)
		duplicate.set_meta("first_person_source", weakref(node))
		duplicate.set_meta("first_person_split", true)
		# Keep the same skeleton path and transform by adding a sibling.
		node.get_parent().add_child(duplicate)
		duplicate.transform = node.transform
		node.set_meta("first_person_split", true)
		node.set_meta("first_person_original", true)
		var sync = BlendShapeSync.new()
		sync.source = node
		sync.target = duplicate
		sync.source_surfaces = source_surfaces
		node.add_child(sync)
		changed = true
	avatar.set_meta("first_person_prepared", true)
	return changed

class BlendShapeSync extends Node:
	var source: MeshInstance3D
	var target: MeshInstance3D
	var source_surfaces: Array[int] = []
	func _process(_delta: float):
		if not is_instance_valid(source) or not is_instance_valid(target): return
		if not target.get_meta("first_person_active", false): return
		if target.visible != source.visible: target.visible = source.visible
		if not target.is_visible_in_tree(): return
		if target.transform != source.transform: target.transform = source.transform
		if target.material_override != source.material_override: target.material_override = source.material_override
		if target.transparency != source.transparency: target.transparency = source.transparency
		for surface in source_surfaces.size():
			var material = source.get_surface_override_material(source_surfaces[surface])
			if target.get_surface_override_material(surface) != material:
				target.set_surface_override_material(surface, material)
		for index in mini(source.get_blend_shape_count(), target.get_blend_shape_count()):
			var value = source.get_blend_shape_value(index)
			if target.get_blend_shape_value(index) != value: target.set_blend_shape_value(index, value)

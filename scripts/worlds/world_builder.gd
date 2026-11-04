extends RefCounted
## Reconstruct reviewed types only. This never loads archive resource paths.
const Reader = preload("res://scripts/worlds/world_package_reader.gd")
const Data = preload("res://scripts/worlds/world_data.gd")
var document: Dictionary = {}
var cache: Dictionary = {}
var error := ""

func build_package(path: String) -> Dictionary:
	var inspected = Reader.new().inspect_package(path)
	if not inspected.ok: return inspected
	document = inspected.document
	cache.clear()
	error = ""
	var path_scene: String = document.manifest.main_scene
	var nodes: Dictionary = {}
	var world: Node
	var spawn = [0.0, 1.0, 0.0]
	for section in document.scenes[path_scene]:
		if section.kind != "node": continue
		var attrs: Dictionary = section.attributes
		var node = _node(attrs.type)
		if node == null:
			if world != null: world.free()
			return Data.failure("Unsupported world node")
		node.name = attrs.name
		var parent = str(attrs.get("parent", ""))
		if world == null:
			world = node
			nodes["."] = world
		else:
			nodes[parent].add_child(node)
			node.owner = world
			nodes[attrs.name if parent == "." else parent + "/" + attrs.name] = node
		for key in section.properties:
			if key.begins_with("metadata/"):
				node.set_meta(key.trim_prefix("metadata/"), section.properties[key])
			else:
				node.set(key, _value(section.properties[key], path_scene, 0))
		if node.get_meta("world_spawn", false) and node is Node3D:
			var transform = node.transform
			var ancestor = node.get_parent()
			while ancestor is Node3D:
				transform = ancestor.transform * transform
				ancestor = ancestor.get_parent()
			spawn = [float(transform.origin.x), float(transform.origin.y), float(transform.origin.z)]
	if world == null: return Data.failure("World has no root node")
	if not error.is_empty():
		world.free()
		return Data.failure(error)
	var scene = PackedScene.new()
	var packed = scene.pack(world)
	world.free()
	if packed != OK: return Data.failure("Cannot pack constructed world")
	return {"ok": true, "scene": scene, "spawn_point": spawn, "revision": inspected.revision, "document": document}

func _node(type: String) -> Node:
	match type:
		"Node": return Node.new()
		"Node3D": return Node3D.new()
		"Marker3D": return Marker3D.new()
		"MeshInstance3D": return MeshInstance3D.new()
		"StaticBody3D": return StaticBody3D.new()
		"RigidBody3D": return RigidBody3D.new()
		"CollisionShape3D": return CollisionShape3D.new()
		"Area3D": return Area3D.new()
		"DirectionalLight3D": return DirectionalLight3D.new()
		"OmniLight3D": return OmniLight3D.new()
		"SpotLight3D": return SpotLight3D.new()
	return null

func _resource(type: String) -> Resource:
	match type:
		"BoxMesh": return BoxMesh.new()
		"SphereMesh": return SphereMesh.new()
		"CylinderMesh": return CylinderMesh.new()
		"PlaneMesh": return PlaneMesh.new()
		"CapsuleMesh": return CapsuleMesh.new()
		"BoxShape3D": return BoxShape3D.new()
		"SphereShape3D": return SphereShape3D.new()
		"CapsuleShape3D": return CapsuleShape3D.new()
		"CylinderShape3D": return CylinderShape3D.new()
		"StandardMaterial3D": return StandardMaterial3D.new()
		"ORMMaterial3D": return ORMMaterial3D.new()
	return null

func _external(path: String, depth: int) -> Resource:
	if cache.has(path): return cache[path]
	if document.textures.has(path):
		var image = Image.new()
		if image.load_png_from_buffer(document.textures[path]) != OK:
			error = "Texture decode failed: " + path
			return null
		image.generate_mipmaps()
		var texture = ImageTexture.create_from_image(image)
		cache[path] = texture
		return texture
	for section in document.scenes.get(path, []):
		if section.kind == "resource":
			var resource = _resource(document.scenes[path][0].attributes.type)
			cache[path] = resource
			for key in section.properties: resource.set(key, _value(section.properties[key], path, depth + 1))
			return resource
	error = "Unsupported external resource: " + path
	return null

func _value(value: Variant, path: String, depth: int) -> Variant:
	if depth > 16:
		error = "Resource dependency depth exceeded"
		return null
	if not value is Dictionary: return value
	var args: Array = value.args
	match value.type:
		"Vector2": return Vector2(args[0], args[1])
		"Vector3": return Vector3(args[0], args[1], args[2])
		"Color": return Color(args[0], args[1], args[2], args[3] if args.size() == 4 else 1.0)
		"Transform3D": return Transform3D(Basis(Vector3(args[0], args[1], args[2]), Vector3(args[3], args[4], args[5]), Vector3(args[6], args[7], args[8])), Vector3(args[9], args[10], args[11]))
		"ExtResource": return _external(document.resources[path].external[args[0]], depth + 1)
		"SubResource":
			var key = path + "#" + args[0]
			if cache.has(key): return cache[key]
			var entry: Dictionary = document.resources[path].sub[args[0]]
			var resource = _resource(entry.type)
			cache[key] = resource
			for property in entry.properties: resource.set(property, _value(entry.properties[property], path, depth + 1))
			return resource
	error = "Unsupported runtime data constructor"
	return null

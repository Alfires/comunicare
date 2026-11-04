extends RefCounted
## Package-to-data boundary. Nothing from the archive is registered or executed.
const Data = preload("res://scripts/worlds/world_data.gd")
const Text = preload("res://scripts/worlds/world_text_parser.gd")
const Zip = preload("res://scripts/worlds/world_zip_reader.gd")
const Extensions = preload("res://scripts/worlds/world_extension_registry.gd")
const NODE_TYPES = ["Node", "Node3D", "Marker3D", "MeshInstance3D", "StaticBody3D", "RigidBody3D", "CollisionShape3D", "Area3D", "DirectionalLight3D", "OmniLight3D", "SpotLight3D"]
const RESOURCE_TYPES = ["BoxMesh", "SphereMesh", "CylinderMesh", "PlaneMesh", "CapsuleMesh", "BoxShape3D", "SphereShape3D", "CapsuleShape3D", "CylinderShape3D", "StandardMaterial3D", "ORMMaterial3D"]
const NODE_PROPERTIES = ["position", "rotation", "scale", "transform", "visible", "mesh", "material_override", "shape", "disabled", "mass", "freeze", "gravity_scale", "collision_layer", "collision_mask", "light_color", "light_energy", "omni_range", "spot_range", "metadata/world_entity_id", "metadata/world_pickup", "metadata/world_spawn"]
const MATERIAL_PROPERTIES = ["albedo_color", "albedo_texture", "metallic", "metallic_texture", "metallic_texture_channel", "roughness", "roughness_texture", "roughness_texture_channel", "normal_enabled", "normal_texture", "normal_scale", "ao_enabled", "ao_texture", "ao_texture_channel", "emission_enabled", "emission", "emission_texture", "emission_energy_multiplier", "uv1_scale", "uv1_offset", "uv2_scale", "uv2_offset", "texture_filter", "texture_repeat", "transparency", "alpha_scissor_threshold", "cull_mode", "shading_mode", "clearcoat_enabled", "clearcoat", "clearcoat_roughness", "clearcoat_texture", "heightmap_enabled", "heightmap_scale", "heightmap_texture", "detail_enabled", "detail_albedo", "detail_normal", "orm_texture"]
var last_error := ""

func inspect_package(path: String, overrides: Dictionary = {}) -> Dictionary:
	last_error = ""
	var limits = {"max_entries": 4096, "max_expanded_bytes": 256 * 1024 * 1024, "max_texture_dimension": 4096}
	for key in overrides:
		if not limits.has(key) or not Data.integer(overrides[key], 0, limits[key]): return _failure("Invalid package limit")
		limits[key] = int(overrides[key])
	var archive = Zip.new().read_archive(path, limits)
	if not archive.ok: return archive
	var files: Dictionary = archive.files
	if not files.has("manifest.json"): return _failure("World metadata missing")
	var parsed = Text.new().parse_json(files["manifest.json"].get_string_from_utf8())
	if not parsed.ok or not parsed.value is Dictionary: return _failure("Invalid manifest: " + parsed.error)
	var manifest: Dictionary = parsed.value
	if not Data.bounded(manifest, 0, [4096]) or not Data.keys_only(manifest, ["format", "schema_version", "world_id", "release", "requires", "main_scene", "script_capabilities", "extensions", "title", "description"]) \
		or manifest.get("format") != "comunicare.world" or manifest.get("schema_version") != 1 \
		or not manifest.get("world_id") is String or manifest.world_id.is_empty() \
		or not manifest.get("release") is String or not Data.safe_path(manifest.get("main_scene")) \
		or not manifest.main_scene.ends_with(".tscn") or not files.has(manifest.main_scene):
		return _failure("Unsupported or invalid world manifest")
	if not manifest.get("requires") is Dictionary or manifest.requires.get("world_api") != 1 or manifest.requires.get("script_api") != 1:
		return _failure("Unsupported world/script API")
	if not manifest.get("script_capabilities", []) is Array: return _failure("Invalid script capabilities")
	for capability in manifest.get("script_capabilities", []):
		if not capability in ["entity.read", "entity.visual", "interaction.events"]: return _failure("Forbidden script capability")
	var extensions = Extensions.new().validate_requirements(manifest.get("extensions", []), {}, files.keys())
	if not extensions.ok: return extensions
	var document = {"entities": {}, "materials": {}, "scenes": {}, "textures": {}, "manifest": manifest, "resources": {}}
	var decoded_texture_bytes = 0
	for name in files:
		var extension: String = name.get_extension().to_lower()
		match extension:
			"tscn", "tres":
				var result = Text.new().parse_resource(files[name].get_string_from_utf8())
				if not result.ok: return _failure(name + ": " + result.error)
				if not _validate_sections(name, result.value, files, document): return _failure(last_error)
				document.scenes[name] = result.value
			"png", "jpg", "jpeg", "webp":
				if not _texture_header(files[name], extension, limits.max_texture_dimension): return _failure("Unsupported/oversized texture: " + name)
				decoded_texture_bytes += _big_u32(files[name], 16) * _big_u32(files[name], 20) * 6
				if decoded_texture_bytes > 256 * 1024 * 1024: return _failure("Aggregate texture budget exceeded")
				document.textures[name] = files[name]
			"json":
				var json = Text.new().parse_json(files[name].get_string_from_utf8())
				if not json.ok: return _failure("Invalid JSON data: " + name)
			_:
				return _failure("Unsupported package file: " + name)
	if not _validate_references(document): return _failure(last_error)
	return {"ok": true, "revision": archive.revision, "document": document}

func _failure(message: String) -> Dictionary:
	last_error = message
	return Data.failure(message)

func _bad(message: String) -> bool:
	last_error = message
	return false

func _validate_sections(path: String, sections: Array, files: Dictionary, document: Dictionary) -> bool:
	if sections.is_empty() or sections[0].kind != ("gd_scene" if path.ends_with(".tscn") else "gd_resource"):
		return _bad("Invalid Godot text header: " + path)
	var ext: Dictionary = {}
	var sub: Dictionary = {}
	var paths: Dictionary = {}
	var main_type = str(sections[0].attributes.get("type", ""))
	if sections[0].attributes.get("format") != 3: return _bad("Only Godot text format 3 is supported")
	if path.ends_with(".tres") and not main_type in RESOURCE_TYPES: return _bad("Unsupported resource type: " + main_type)
	for section in sections:
		var attrs: Dictionary = section.attributes
		var properties: Dictionary = section.properties
		match section.kind:
			"gd_scene", "gd_resource":
				if section != sections[0] or not Data.keys_only(attrs, ["load_steps", "format", "uid", "type"]) or not properties.is_empty(): return _bad("Invalid document header")
			"ext_resource":
				if not Data.keys_only(attrs, ["type", "path", "id", "uid"]) or not properties.is_empty() or not attrs.get("id") is String or ext.has(attrs.id) \
					or not attrs.get("path") is String or not attrs.path.begins_with("res://"):
					return _bad("Invalid external resource")
				var relative: String = attrs.path.trim_prefix("res://")
				if not Data.safe_path(relative) or not files.has(relative) or not attrs.get("type") in ["Material", "StandardMaterial3D", "ORMMaterial3D", "Texture2D", "PackedScene"]:
					return _bad("Missing or unsupported resource: " + relative)
				ext[attrs.id] = relative
			"sub_resource", "resource":
				var type = str(attrs.get("type", main_type))
				if not type in RESOURCE_TYPES or not Data.keys_only(attrs, ["type", "id"]): return _bad("Unsupported built-in resource: " + type)
				if section.kind == "sub_resource":
					if not attrs.get("id") is String or sub.has(attrs.id): return _bad("Duplicate/missing subresource ID")
					sub[attrs.id] = {"type": type, "properties": properties}
				if not _properties(type, properties): return false
				if section.kind == "resource": document.materials[path] = _material(properties, ext)
			"node":
				if not Data.keys_only(attrs, ["name", "type", "parent", "index", "unique_id"]) or not attrs.get("name") is String or not attrs.get("type") in NODE_TYPES:
					return _bad("Unsupported node/scene instance")
				if "/" in attrs.name or attrs.name in ["", ".", ".."]: return _bad("Invalid node name")
				var parent = str(attrs.get("parent", ""))
				var node_path = "." if parent.is_empty() else (attrs.name if parent == "." else parent + "/" + attrs.name)
				if paths.has(node_path) or (not parent.is_empty() and not paths.has(parent)): return _bad("Invalid scene hierarchy")
				paths[node_path] = true
				if not _properties(attrs.type, properties): return false
				if properties.has("metadata/world_entity_id"):
					var id = properties["metadata/world_entity_id"]
					# Main scene entities only; reusable scenes need scoped IDs at build time.
					if path == document.manifest.main_scene:
						if not id is String or id.is_empty() or document.entities.has(id): return _bad("Invalid or duplicate entity ID")
						document.entities[id] = {"path": node_path, "pickup": properties.get("metadata/world_pickup", false), "spawn": properties.get("metadata/world_spawn", false)}
			_:
				return _bad("Unsupported scene section: " + section.kind)
	document.resources[path] = {"external": ext, "sub": sub}
	return true

func _properties(type: String, properties: Dictionary) -> bool:
	var allowed: Array = NODE_PROPERTIES if type in NODE_TYPES else MATERIAL_PROPERTIES if type in ["StandardMaterial3D", "ORMMaterial3D"] else ["size", "radius", "height", "top_radius", "bottom_radius", "radial_segments", "rings", "material", "subdivide_width", "subdivide_depth", "subdivide_height"]
	# Use only engine-owned reflection metadata to check declared property types;
	# no package-selected constructor, class lookup or property setter is invoked.
	var definitions: Array = ClassDB.class_get_property_list(type)
	var schema: Dictionary = {}
	for definition in definitions: schema[str(definition.name)] = definition
	for key in properties:
		if not key in allowed or not _value_safe(properties[key], 0): return _bad("Unsupported/invalid property: " + type + "." + key)
		var value = properties[key]
		if not key.begins_with("metadata/"):
			if not schema.has(key): return _bad("Property is not present on reviewed built-in type")
			if not _matches_type(value, int(schema[key].type)): return _bad("Property type mismatch: " + key)
		if key in ["position", "rotation", "scale", "uv1_scale", "uv1_offset", "uv2_scale", "uv2_offset"] or (key == "size" and type in ["BoxMesh", "BoxShape3D"]):
			if not value is Dictionary or value.get("type") != "Vector3" or value.args.size() != 3: return _bad("Property needs Vector3: " + key)
		elif key == "size" and type == "PlaneMesh":
			if not value is Dictionary or value.get("type") != "Vector2" or value.args.size() != 2: return _bad("Plane size needs Vector2")
		elif key.ends_with("_enabled") or key in ["visible", "disabled", "freeze", "texture_repeat", "metadata/world_pickup", "metadata/world_spawn"]:
			if not value is bool: return _bad("Property needs boolean: " + key)
		elif key == "metadata/world_entity_id":
			if not value is String: return _bad("Entity ID must be text")
		elif key in ["mesh", "material", "material_override", "shape"] or key.ends_with("_texture") or key in ["detail_albedo", "detail_normal"]:
			if not value is Dictionary or not value.get("type") in ["ExtResource", "SubResource"] or value.args.size() != 1 or not value.args[0] is String: return _bad("Property needs resource reference: " + key)
		elif key in ["albedo_color", "light_color", "emission"]:
			if not value is Dictionary or value.get("type") != "Color" or not value.args.size() in [3, 4]: return _bad("Property needs Color: " + key)
		elif key == "transform":
			if not value is Dictionary or value.get("type") != "Transform3D" or value.args.size() != 12: return _bad("Property needs Transform3D")
		else:
			if not (value is int or value is float): return _bad("Property needs number: " + key)
			if key.begins_with("subdivide_") and not Data.integer(value, 0, 64): return _bad("Mesh subdivision budget")
			if key in ["radial_segments", "rings"] and not Data.integer(value, 1, 128): return _bad("Mesh segment budget")
			if key in ["radius", "height", "top_radius", "bottom_radius", "mass"] and (value <= 0 or value > 1000): return _bad("Invalid geometry dimension")
			if key in ["transparency", "cull_mode", "shading_mode", "texture_filter", "metallic_texture_channel", "roughness_texture_channel", "ao_texture_channel"] and not Data.integer(value, 0, 2 if key == "cull_mode" else 5): return _bad("Material enum out of bounds")
	return true

func _matches_type(value: Variant, expected: int) -> bool:
	match expected:
		TYPE_BOOL: return value is bool
		TYPE_INT: return Data.integer(value, -2147483648, 2147483647)
		TYPE_FLOAT: return value is int or value is float
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR, TYPE_TRANSFORM3D:
			if not value is Dictionary: return false
			var name = {TYPE_VECTOR2: "Vector2", TYPE_VECTOR3: "Vector3", TYPE_COLOR: "Color", TYPE_TRANSFORM3D: "Transform3D"}[expected]
			if value.get("type") != name: return false
			for coordinate in value.args:
				if not (coordinate is int or coordinate is float): return false
			return true
		TYPE_OBJECT:
			return value is Dictionary and value.get("type") in ["ExtResource", "SubResource"]
	return false

func _value_safe(value: Variant, depth: int) -> bool:
	if depth > 16: return false
	if value is bool or value == null: return true
	if value is String: return value.length() < 1024
	if value is int or value is float: return is_finite(float(value)) and absf(float(value)) <= 1000000
	if value is Dictionary and Data.keys_only(value, ["type", "args"]) and value.get("args") is Array:
		if not value.get("type") in ["Vector2", "Vector3", "Vector4", "Color", "Quaternion", "Basis", "Transform3D", "ExtResource", "SubResource"]: return false
		for argument in value.args:
			if not _value_safe(argument, depth + 1): return false
		return value.args.size() <= 12
	return false

func _material(properties: Dictionary, external: Dictionary) -> Dictionary:
	var material = {"textures": {}, "uv1_scale": [1.0, 1.0, 1.0], "metallic": properties.get("metallic", 0.0), "roughness": properties.get("roughness", 1.0)}
	for key in properties:
		var value = properties[key]
		if key.ends_with("_texture") and value is Dictionary and value.get("type") == "ExtResource" and value.args.size() == 1:
			material.textures[key.trim_suffix("_texture")] = external.get(value.args[0], "")
	if properties.get("uv1_scale") is Dictionary:
		material.uv1_scale = []
		for coordinate in properties.uv1_scale.args: material.uv1_scale.append(float(coordinate))
	return material

func _validate_references(document: Dictionary) -> bool:
	for path in document.scenes:
		var resources: Dictionary = document.resources[path]
		for section in document.scenes[path]:
			for value in section.properties.values():
				if not _references(value, resources): return _bad("Unresolved resource reference: " + path)
			for key in section.properties:
				var value = section.properties[key]
				if value is Dictionary and value.get("type") in ["ExtResource", "SubResource"]:
					var target_type = ""
					if value.type == "SubResource":
						target_type = resources.sub[value.args[0]].type
					else:
						var target: String = resources.external[value.args[0]]
						if document.textures.has(target): target_type = "Texture2D"
						elif document.scenes.has(target): target_type = str(document.scenes[target][0].attributes.get("type", "PackedScene"))
					if key in ["material", "material_override"] and not target_type in ["StandardMaterial3D", "ORMMaterial3D"]: return _bad("Material reference has wrong type")
					if key == "mesh" and not target_type.ends_with("Mesh"): return _bad("Mesh reference has wrong type")
					if key == "shape" and not target_type.ends_with("Shape3D"): return _bad("Collision reference has wrong type")
					if (key.ends_with("_texture") or key in ["detail_albedo", "detail_normal"]) and target_type != "Texture2D": return _bad("Texture reference has wrong type")
	return true

func _references(value: Variant, resources: Dictionary) -> bool:
	if value is Dictionary:
		if value.get("type") in ["ExtResource", "SubResource"]:
			return value.args.size() == 1 and (resources.external if value.type == "ExtResource" else resources.sub).has(value.args[0])
		for argument in value.get("args", []):
			if not _references(argument, resources): return false
	return true

func _texture_header(bytes: PackedByteArray, extension: String, maximum: int) -> bool:
	# Initial decoder profile deliberately PNG-only until other header checks land.
	if extension != "png" or bytes.size() < 33 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]): return false
	var width = (int(bytes[16]) << 24) | (int(bytes[17]) << 16) | (int(bytes[18]) << 8) | int(bytes[19])
	var height = (int(bytes[20]) << 24) | (int(bytes[21]) << 16) | (int(bytes[22]) << 8) | int(bytes[23])
	if width <= 0 or height <= 0 or width > maximum or height > maximum or width * height * 4 > 64 * 1024 * 1024: return false
	var cursor = 8
	var has_data = false
	var has_end = false
	while cursor + 12 <= bytes.size():
		var length = (int(bytes[cursor]) << 24) | (int(bytes[cursor + 1]) << 16) | (int(bytes[cursor + 2]) << 8) | int(bytes[cursor + 3])
		if length < 0 or cursor + 12 + length > bytes.size(): return false
		var kind = bytes.slice(cursor + 4, cursor + 8).get_string_from_ascii()
		if Zip.new()._crc(bytes.slice(cursor + 4, cursor + 8 + length)) != _big_u32(bytes, cursor + 8 + length): return false
		if kind == "IDAT": has_data = true
		if kind == "IEND":
			has_end = length == 0 and cursor + 12 == bytes.size()
			break
		cursor += 12 + length
	return has_data and has_end

func _big_u32(bytes: PackedByteArray, offset: int) -> int:
	return (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])

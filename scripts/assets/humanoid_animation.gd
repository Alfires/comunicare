extends RefCounted
## Data-only GLB/VRMA reader. Never loads scripts, scenes or callback tracks.

const MAX_BYTES = 16 * 1024 * 1024
const MAX_KEYS = 100000
var last_error := ""

func read_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES or file.get_length() < 20:
		return _fail("Animation must be a self-contained GLB/VRMA up to 16 MiB.")
	return read_bytes(file.get_buffer(file.get_length()))

func document(bytes: PackedByteArray, byte_limit: int = MAX_BYTES) -> Dictionary:
	if bytes.size() < 20 or bytes.size() > byte_limit or bytes.decode_u32(0) != 0x46546c67 \
		or bytes.decode_u32(4) != 2 or bytes.decode_u32(8) != bytes.size():
		return {}
	var offset := 12
	var json: Dictionary = {}
	var binary = PackedByteArray()
	var binary_seen := false
	while offset + 8 <= bytes.size():
		var length = bytes.decode_u32(offset)
		var type = bytes.decode_u32(offset + 4)
		if offset == 12 and type != 0x4e4f534a: return {}
		offset += 8
		if length % 4 != 0 or length > bytes.size() - offset:
			return {}
		if type == 0x4e4f534a:
			if not json.is_empty():
				return {}
			var parser = JSON.new()
			if parser.parse(bytes.slice(offset, offset + length).get_string_from_utf8()) != OK or not parser.data is Dictionary:
				return {}
			json = parser.data
		elif type == 0x004e4942:
			if binary_seen: return {}
			binary_seen = true
			binary = bytes.slice(offset, offset + length)
		offset += length
	if offset != bytes.size() or json.is_empty() or not json.get("nodes", []) is Array \
		or json.get("nodes", []).size() > 4096 or not json.get("buffers", []) is Array \
		or not json.get("images", []) is Array:
		return {}
	if json.get("buffers", []).size() > 1: return {}
	for buffer in json.get("buffers", []):
		if not buffer is Dictionary or buffer.has("uri"):
			return {}
		var size = buffer.get("byteLength", -1)
		if not _integer(size) or size < 0 or size > binary.size(): return {}
	for image in json.get("images", []):
		if not image is Dictionary or image.has("uri"):
			return {}
	return {"json": json, "binary": binary}

func humanoid_nodes(json: Dictionary) -> Dictionary:
	var extensions = json.get("extensions", {})
	if not extensions is Dictionary:
		return {}
	var mapping: Dictionary = {}
	for name in ["VRMC_vrm_animation", "VRMC_vrm"]:
		var extension = extensions.get(name, {})
		if extension is Dictionary and extension.get("humanoid", {}) is Dictionary:
			var bones = extension.get("humanoid", {}).get("humanBones", {})
			if bones is Dictionary:
				for bone in bones:
					if bones[bone] is Dictionary and _index(bones[bone].get("node"), json.get("nodes", []).size()):
						mapping[bone] = int(bones[bone].node)
	var legacy = extensions.get("VRM", {})
	if mapping.is_empty() and legacy is Dictionary and legacy.get("humanoid", {}) is Dictionary:
		var bones = legacy.get("humanoid", {}).get("humanBones", [])
		if bones is Array:
			for bone in bones:
				if bone is Dictionary and bone.get("bone") is String and _index(bone.get("node"), json.get("nodes", []).size()):
					mapping[bone.bone] = int(bone.node)
	return mapping

func read_bytes(bytes: PackedByteArray) -> Dictionary:
	var doc = document(bytes)
	if doc.is_empty():
		return _fail("Malformed GLB or external dependencies are not supported.")
	var json: Dictionary = doc.json
	var mapping = humanoid_nodes(json)
	if mapping.is_empty():
		return _fail("Humanoid metadata is required (VRMA or VRM-mapped GLB).")
	var by_node: Dictionary = {}
	for bone in mapping:
		if by_node.has(mapping[bone]):
			return _fail("Duplicate humanoid node mapping.")
		by_node[mapping[bone]] = bone
	var parents: Dictionary = {}
	for index in json.nodes.size():
		var node = json.nodes[index]
		if not node is Dictionary or not node.get("children", []) is Array:
			return _fail("Invalid hierarchy.")
		for child in node.get("children", []):
			if not _index(child, json.nodes.size()) or parents.has(int(child)):
				return _fail("Invalid or multiply-parented hierarchy.")
			parents[int(child)] = index
	# Validate every component once, including unanimated/disconnected nodes.
	var checked := {}
	for index in json.nodes.size():
		var visiting := {}
		var cursor = index
		while cursor >= 0 and not checked.has(cursor):
			if visiting.has(cursor): return _fail("Cyclic node hierarchy.")
			visiting[cursor] = true
			cursor = parents.get(cursor, -1)
		checked.merge(visiting)
	var clips: Array = []
	var animations = json.get("animations", [])
	if not animations is Array or animations.is_empty() or animations.size() > 64:
		return _fail("Animation file has no clips or exceeds the 64-clip limit.")
	var total_keys := 0
	for entry in animations:
		if not entry is Dictionary or not entry.get("samplers") is Array or not entry.get("channels") is Array:
			return _fail("Malformed animation channels.")
		if entry.channels.size() > 256 or entry.samplers.size() > 256:
			return _fail("Clip exceeds channel budget.")
		var clip = {"name": str(entry.get("name", "Clip %s" % (clips.size() + 1))).left(128), "duration": 0.0, "tracks": []}
		var targets: Dictionary = {}
		for channel in entry.channels:
			if not channel is Dictionary or not channel.get("target") is Dictionary or not _index(channel.get("sampler"), entry.samplers.size()):
				return _fail("Invalid animation target/sampler.")
			var target: Dictionary = channel.target
			if not _index(target.get("node"), json.nodes.size()):
				return _fail("Invalid target node.")
			var node_id = int(target.node)
			if not by_node.has(node_id):
				return _fail("Expression, gaze and non-humanoid tracks are not supported yet.")
			# Hips translation is deliberately deferred; never apply root motion.
			if target.get("path") != "rotation":
				return _fail("This importer currently supports rotation-only humanoid clips.")
			if targets.has(node_id):
				return _fail("Duplicate rotation channel.")
			targets[node_id] = true
			var sampler = entry.samplers[int(channel.sampler)]
			if not sampler is Dictionary or sampler.get("interpolation", "LINEAR") not in ["LINEAR", "STEP"]:
				return _fail("Only LINEAR and STEP interpolation are supported.")
			var times = _accessor(json, doc.binary, sampler.get("input"), "SCALAR", 1)
			var values = _accessor(json, doc.binary, sampler.get("output"), "VEC4", 4)
			if times.is_empty() or values.size() != times.size() * 4:
				return _fail("Invalid keyframe accessors.")
			total_keys += times.size()
			if total_keys > MAX_KEYS:
				return _fail("Animation exceeds keyframe budget.")
			var node = json.nodes[node_id]
			if not node is Dictionary or node.has("matrix"):
				return _fail("Matrix-based rest transforms are unsupported.")
			var rest = _quaternion(node.get("rotation", [0, 0, 0, 1]))
			if rest == Quaternion(0, 0, 0, 0):
				return _fail("Invalid rest rotation.")
			var global_rest = _global_rest_rotation(json.nodes, parents, node_id)
			if global_rest == Quaternion(0, 0, 0, 0):
				return _fail("Invalid or cyclic rest hierarchy.")
			var keys: Array = []
			var previous := -1.0
			for i in times.size():
				var time = times[i]
				if time < 0 or time <= previous or time > 600:
					return _fail("Key times must increase within ten minutes.")
				previous = time
				var rotation = _quaternion(values.slice(i * 4, i * 4 + 4))
				if rotation == Quaternion(0, 0, 0, 0):
					return _fail("Invalid rotation key.")
				keys.append({"time": time, "rotation": rest.inverse() * rotation})
			clip.duration = maxf(clip.duration, times[-1])
			clip.tracks.append({"bone": by_node[node_id], "keys": keys, "source_rest": global_rest,
				"step": sampler.get("interpolation") == "STEP"})
		if clip.tracks.is_empty() or clip.duration <= 0:
			return _fail("Clip is empty or has zero duration.")
		clips.append(clip)
	last_error = ""
	var hashing = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return {"clips": clips, "hash": hashing.finish().hex_encode(), "schema": 1}

func _accessor(json: Dictionary, binary: PackedByteArray, id: Variant, type: String, width: int) -> Array:
	var accessors = json.get("accessors", [])
	var views = json.get("bufferViews", [])
	if not accessors is Array or not views is Array or not _index(id, accessors.size()):
		return []
	var accessor = accessors[int(id)]
	if not accessor is Dictionary or accessor.has("sparse") or accessor.get("normalized", false) != false or accessor.get("componentType") != 5126 \
		or accessor.get("type") != type or not _index(accessor.get("bufferView"), views.size()) \
		or not _integer(accessor.get("count")) or accessor.count <= 0 or accessor.count > MAX_KEYS:
		return []
	var view = views[int(accessor.bufferView)]
	if not view is Dictionary or view.get("buffer", 0) != 0:
		return []
	var offset = view.get("byteOffset", 0)
	var length = view.get("byteLength", -1)
	var start = accessor.get("byteOffset", 0)
	var stride = view.get("byteStride", width * 4)
	if not _integer(offset) or not _integer(length) or not _integer(start) or not _integer(stride) \
		or offset < 0 or length < 0 or start < 0 or stride < width * 4 or stride > 256 \
		or int(offset) % 4 != 0 or int(start) % 4 != 0 or int(stride) % 4 != 0 \
		or offset + length > binary.size() or start + (accessor.count - 1) * stride + width * 4 > length:
		return []
	var result: Array = []
	for i in int(accessor.count):
		for component in width:
			var value = binary.decode_float(int(offset + start + i * stride + component * 4))
			if not is_finite(value):
				return []
			result.append(value)
	return result

func _quaternion(values: Variant) -> Quaternion:
	if not values is Array or values.size() != 4:
		return Quaternion(0, 0, 0, 0)
	for value in values:
		if not (value is float or value is int) or not is_finite(value):
			return Quaternion(0, 0, 0, 0)
	var result = Quaternion(values[0], values[1], values[2], values[3])
	return result.normalized() if result.length_squared() > 0.0001 else Quaternion(0, 0, 0, 0)

func _global_rest_rotation(nodes: Array, parents: Dictionary, start: int) -> Quaternion:
	var rotation = Quaternion.IDENTITY
	var index = start
	var visited: Dictionary = {}
	while index >= 0:
		if visited.has(index) or visited.size() > 256:
			return Quaternion(0, 0, 0, 0)
		visited[index] = true
		var node: Dictionary = nodes[index]
		if node.has("matrix"):
			return Quaternion(0, 0, 0, 0)
		var local = _quaternion(node.get("rotation", [0, 0, 0, 1]))
		if local == Quaternion(0, 0, 0, 0):
			return local
		rotation = local * rotation
		index = parents.get(index, -1)
	return rotation

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value)

func _index(value: Variant, size: int) -> bool:
	return _integer(value) and value >= 0 and value < size

func _fail(message: String) -> Dictionary:
	last_error = message
	return {}

func bind_clip(clip: Dictionary, avatar: Node3D) -> Animation:
	last_error = ""
	var skeleton = _skeleton(avatar)
	if skeleton == null:
		last_error = "Avatar has no skeleton."
		return null
	var mapping: Dictionary = avatar.get_meta("humanoid_bones", {})
	if mapping.is_empty():
		last_error = "Avatar has no validated humanoid mapping."
		return null
	var animation = Animation.new()
	animation.length = clip.duration
	for source in clip.tracks:
		if not mapping.has(source.bone):
			if source.get("optional", false): continue
			last_error = "Avatar is missing humanoid bone: " + source.bone
			return null
		var index = skeleton.find_bone(mapping[source.bone])
		if index < 0:
			last_error = "Avatar mapped bone is missing: " + str(mapping[source.bone])
			return null
		var track = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath(str(avatar.get_path_to(skeleton)) + ":" + skeleton.get_bone_name(index)))
		if source.get("step", false):
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
		var rest = skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		var target_global = skeleton.get_bone_global_rest(index).basis.get_rotation_quaternion()
		var source_global: Quaternion = source.get("source_rest", Quaternion.IDENTITY)
		# Legacy VRM 0.x uses the opposite humanoid forward convention. Bone
		# labels alone do not reveal that its left arm extends along -X.
		if source.get("reference_space") == "gltf_humanoid" and avatar.get_meta("vrm_legacy_orientation", false):
			source_global = Quaternion(Vector3.UP, PI) * source_global
		var conversion = target_global.inverse() * source_global if source.has("source_rest") else Quaternion.IDENTITY
		for key in source.keys:
			animation.rotation_track_insert_key(track, key.time, rest * conversion * key.rotation * conversion.inverse())
	return animation

func _skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _skeleton(child)
		if found != null:
			return found
	return null

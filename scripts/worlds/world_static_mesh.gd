extends RefCounted
## Data-only triangle mesh. No engine resources, URIs, skins or executable fields.
const MAX_VERTICES = 50000
const MAX_INDICES = 150000

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 1: return false
	for key in value:
		if key not in ["schema", "vertices", "indices", "normals", "uv"]: return false
	if not value.get("vertices") is Array or not value.get("indices") is Array: return false
	var count: int = value.vertices.size()
	if count < 3 or count > MAX_VERTICES or value.indices.is_empty() or value.indices.size() > MAX_INDICES or value.indices.size() % 3 != 0: return false
	for field in ["vertices", "normals", "uv"]:
		if not value.has(field): continue
		if not value[field] is Array or value[field].size() != count: return false
		for vector in value[field]:
			if not vector is Array or vector.size() != (2 if field == "uv" else 3): return false
			for number in vector:
				if not (number is float or number is int) or not is_finite(float(number)) or absf(number) > 10000: return false
	for index in value.indices:
		if not (index is float or index is int) or not is_finite(float(index)) or index != floor(index) or index < 0 or index >= count: return false
	return true

static func build(value: Dictionary) -> ArrayMesh:
	if not valid(value): return null
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices = PackedVector3Array()
	for vector in value.vertices: vertices.append(Vector3(vector[0], vector[1], vector[2]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(value.indices)
	if value.has("normals"):
		var normals = PackedVector3Array()
		for vector in value.normals: normals.append(Vector3(vector[0], vector[1], vector[2]).normalized())
		arrays[Mesh.ARRAY_NORMAL] = normals
	if value.has("uv"):
		var uv = PackedVector2Array()
		for vector in value.uv: uv.append(Vector2(vector[0], vector[1]))
		arrays[Mesh.ARRAY_TEX_UV] = uv
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

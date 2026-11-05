extends RefCounted
## Explicit in-place adaptation; keep rotations, remove positional root motion.
func convert(bytes: PackedByteArray) -> PackedByteArray:
	var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
	var document = reader.document(bytes)
	if document.is_empty(): return PackedByteArray()
	for animation in document.json.get("animations", []):
		if not animation is Dictionary or not animation.get("channels") is Array: return PackedByteArray()
		animation.channels = animation.channels.filter(func(channel): return channel.get("target", {}).get("path") != "translation")
	var json = JSON.stringify(document.json).to_utf8_buffer()
	while json.size() % 4: json.append(32)
	var binary: PackedByteArray = document.binary
	while binary.size() % 4: binary.append(0)
	var result = PackedByteArray()
	result.resize(20)
	result.encode_u32(0, 0x46546c67)
	result.encode_u32(4, 2)
	result.encode_u32(8, 28 + json.size() + binary.size())
	result.encode_u32(12, json.size())
	result.encode_u32(16, 0x4e4f534a)
	result.append_array(json)
	var header = PackedByteArray()
	header.resize(8)
	header.encode_u32(0, binary.size())
	header.encode_u32(4, 0x004e4942)
	result.append_array(header)
	result.append_array(binary)
	return result if not reader.read_bytes(result).is_empty() else PackedByteArray()

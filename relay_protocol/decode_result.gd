class_name DecodeResult
extends RefCounted
## Quiet bounded JSON ingress. Reject excessive nesting before recursive parse.
static func json_value(bytes: PackedByteArray, max_bytes: int) -> Dictionary:
	if bytes.is_empty() or bytes.size() > max_bytes: return {"ok": false, "error": "size"}
	var depth := 0
	var quoted := false
	var escaped := false
	for byte in bytes:
		if quoted:
			if escaped: escaped = false
			elif byte == 92: escaped = true
			elif byte == 34: quoted = false
		elif byte == 34: quoted = true
		elif byte in [91, 123]:
			depth += 1
			if depth > 32: return {"ok": false, "error": "depth"}
		elif byte in [93, 125]: depth -= 1
	var parser = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK: return {"ok": false, "error": "json"}
	return {"ok": true, "value": parser.data}

static func json_object(bytes: PackedByteArray, max_bytes: int) -> Dictionary:
	var result = json_value(bytes, max_bytes)
	if result.ok and not result.value is Dictionary: return {"ok": false, "error": "object_required"}
	return result

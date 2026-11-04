extends RefCounted
## Registry is application-owned. Worlds may request data schemas, never code.
const Data = preload("res://scripts/worlds/world_data.gd")

func validate_requirements(requirements: Variant, installed: Dictionary, package_paths: Array) -> Dictionary:
	if not requirements is Array or requirements.size() > 16:
		return Data.failure("Invalid extension requirements")
	var seen: Dictionary = {}
	for entry in requirements:
		if not entry is Dictionary or not Data.keys_only(entry, ["id", "data_schema", "required", "data"]):
			return Data.failure("Extension declarations cannot include executable fields")
		if not entry.get("id") is String or entry.id.length() > 128 or seen.has(entry.id) \
			or not Data.integer(entry.get("data_schema"), 1, 65535) or not entry.get("required") is bool \
			or not Data.safe_path(entry.get("data")) or not entry.data in package_paths:
			return Data.failure("Invalid, duplicate or missing extension data")
		seen[entry.id] = true
		if not installed.has(entry.id) or not entry.data_schema in installed[entry.id].get("data_schemas", []):
			# Optional integrations need a real fallback schema, not silent removal.
			return Data.failure("Unsupported world extension: " + entry.id)
	return {"ok": true}

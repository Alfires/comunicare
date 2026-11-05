@tool
extends RefCounted
const Data = preload("res://scripts/worlds/world_data.gd")

func validate(document: Variant) -> Dictionary:
	if not document is Dictionary or not Data.bounded(document) or document.get("schema") != 1:
		return Data.failure("Unsupported or oversized authoring document")
	if not Data.keys_only(document, ["schema", "world_id", "title", "entities", "assets", "behaviors", "capabilities", "revision"]): return Data.failure("Unknown project field")
	if not document.get("world_id") is String or document.world_id.is_empty() or not document.get("title") is String: return Data.failure("Missing world identity/title")
	for field in ["entities", "assets", "behaviors", "capabilities"]:
		if not document.get(field) is Array: return Data.failure("Missing project array: " + field)
	# First release exports primitives only; never silently discard assets.
	if not document.assets.is_empty(): return Data.failure("External asset authoring is not supported yet; use primitive entities")
	if document.entities.size() > 256: return Data.failure("Maximum 256 entities")
	var ids: Array = []
	var spawns := 0
	for entity in document.entities:
		if not entity is Dictionary or not Data.keys_only(entity, ["id", "name", "type", "position", "collider"]): return Data.failure("Invalid entity fields")
		if not entity.get("id") is String or entity.id.is_empty() or entity.id.length() > 128 or entity.id in ids: return Data.failure("Missing/duplicate entity ID")
		if not entity.get("name") is String or entity.get("type") not in ["spawn", "scenery", "pickup", "interactable"]: return Data.failure("Unsupported entity")
		if not entity.get("position") is Array or entity.position.size() != 3: return Data.failure("Invalid position")
		for coordinate in entity.position:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(coordinate) > 10000: return Data.failure("Invalid coordinate")
		if entity.type == "spawn": spawns += 1
		else:
			var collider = entity.get("collider", {})
			if not collider is Dictionary or not Data.keys_only(collider, ["type", "size"]) or collider.get("type") != "box" or not collider.get("size") is Array or collider.size.size() != 3: return Data.failure("Entity needs box collider")
			for dimension in collider.size:
				if not (dimension is int or dimension is float) or not is_finite(float(dimension)) or dimension < 0.01 or dimension > 100: return Data.failure("Invalid collider size")
		ids.append(entity.id)
	if spawns != 1: return Data.failure("Project needs exactly one spawn")
	for capability in document.capabilities:
		if capability not in ["entity.visual", "storage.local", "player.checkpoint"]: return Data.failure("Unsupported capability")
	for behavior in document.behaviors:
		if not behavior is Dictionary or not Data.keys_only(behavior, ["entity", "event", "actions"]) or behavior.get("entity") not in ids or behavior.get("event") not in ["start", "tick", "use", "grab", "release"]: return Data.failure("Invalid behavior binding")
		var checked = preload("res://scripts/worlds/world_script_vm.gd").new().run_event(behavior.get("actions"), {"entities": ids, "capabilities": document.capabilities})
		if not checked.ok: return checked
	return {"ok": true}

func save_project(document: Dictionary, path: String) -> Dictionary:
	var checked = validate(document)
	if not checked.ok: return checked
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return Data.failure("Cannot create project directory")
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return Data.failure("Cannot write project")
	file.store_string(JSON.stringify(document, "\t"))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK: return Data.failure("Cannot commit project")
	return {"ok": true}

func load_project(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1024 * 1024: return Data.failure("Unreadable/oversized project")
	var parsed = preload("res://scripts/worlds/world_text_parser.gd").new().parse_json(file.get_as_text())
	if not parsed.ok: return Data.failure(parsed.error)
	var checked = validate(parsed.value)
	if checked.ok: checked.document = parsed.value
	return checked

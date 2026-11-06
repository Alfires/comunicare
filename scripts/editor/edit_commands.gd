extends RefCounted
const Document = preload("res://addons/comunicare_world_tools/authoring_document.gd")
const Data = preload("res://scripts/worlds/world_data.gd")
func apply_operation(document: Dictionary, operation: Dictionary) -> Dictionary:
	if not Document.new().validate(document).ok: return _fail("Invalid project")
	if not Data.integer(document.get("revision", 0), 0, 2147483646) or not Data.integer(operation.get("revision"), 0, 2147483646): return _fail("Invalid or exhausted revision")
	if not Data.keys_only(operation, ["id", "generation", "revision", "op", "entity", "position"]): return _fail("Unsupported operation field")
	if operation.get("op") != "set_transform" or operation.get("revision") != document.get("revision", 0): return _fail("Unsupported or stale operation")
	var copy = document.duplicate(true)
	for entity in copy.entities:
		if entity.id != operation.get("entity"): continue
		var inverse = {"op": "set_transform", "entity": entity.id, "position": entity.position.duplicate(), "revision": int(document.get("revision", 0)) + 1}
		if not operation.get("position") is Array: return _fail("Invalid position")
		entity.position = operation.position.duplicate(true)
		copy.revision = inverse.revision
		var checked = Document.new().validate(copy)
		if not checked.ok: return checked
		return {"ok": true, "document": copy, "inverse": inverse}
	return _fail("Unknown entity")
func undo_operation(document: Dictionary, inverse: Dictionary) -> Dictionary:
	return apply_operation(document, inverse)
func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

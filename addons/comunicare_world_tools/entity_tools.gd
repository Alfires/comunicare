@tool
extends RefCounted
const Document = preload("res://addons/comunicare_world_tools/authoring_document.gd")

func update_entity(source: Dictionary, id: String, name: String, position: Array, size: Array) -> Dictionary:
	var checked = Document.new().validate(source)
	if not checked.ok: return checked
	var copy = source.duplicate(true)
	for entity in copy.get("entities", []):
		if entity.id != id: continue
		entity.name = name
		entity.position = position.duplicate()
		if entity.type != "spawn": entity.collider = {"type": "box", "size": size.duplicate()}
		return _checked(copy)
	return {"ok": false, "error": "Select an existing entity"}

func delete_entity(source: Dictionary, id: String) -> Dictionary:
	var checked = Document.new().validate(source)
	if not checked.ok: return checked
	var copy = source.duplicate(true)
	var count = copy.get("entities", []).size()
	copy.entities = copy.get("entities", []).filter(func(entity): return entity.id != id)
	if copy.entities.size() == count: return {"ok": false, "error": "Select an existing entity"}
	# Validator rejects deletion of the sole spawn or any referenced target.
	# Never silently remove dependent gameplay to make deletion succeed.
	return _checked(copy)

func _checked(copy: Dictionary) -> Dictionary:
	var result = Document.new().validate(copy)
	if result.ok: result.document = copy
	return result

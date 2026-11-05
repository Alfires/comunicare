@tool
extends RefCounted
const Document = preload("res://addons/comunicare_world_tools/authoring_document.gd")

func make_pickup(document: Dictionary, id: String) -> Dictionary:
	var copy = document.duplicate(true)
	for entity in copy.get("entities", []):
		if entity.id == id:
			entity.type = "pickup"
			entity.collider = entity.get("collider", {"type": "box", "size": [1, 1, 1]})
			return _result(copy)
	return {"ok": false, "error": "Unknown target"}

func bind_behavior(document: Dictionary, id: String, event: String, actions: Array) -> Dictionary:
	for action in actions:
		if not action is Dictionary: return {"ok": false, "error": "Action must be a dictionary"}
	var copy = document.duplicate(true)
	if actions.any(func(action): return action.get("capability") == "entity.visual") and not "entity.visual" in copy.capabilities: copy.capabilities.append("entity.visual")
	copy.behaviors.append({"entity": id, "event": event, "actions": actions.duplicate(true)})
	return _result(copy)

func duplicate_entity(document: Dictionary, id: String) -> Dictionary:
	var copy = document.duplicate(true)
	for entity in document.entities:
		if entity.id == id:
			if entity.type == "spawn": return {"ok": false, "error": "Only one spawn is allowed"}
			var duplicate = entity.duplicate(true)
			duplicate.id = Crypto.new().generate_random_bytes(16).hex_encode()
			duplicate.name += " copy"
			copy.entities.append(duplicate)
			var result = _result(copy)
			result.entity_id = duplicate.id
			return result
	return {"ok": false, "error": "Unknown target"}

func _result(document: Dictionary) -> Dictionary:
	var result = Document.new().validate(document)
	if result.ok: result.document = document
	return result

@tool
extends RefCounted
const Document = preload("res://addons/comunicare_world_tools/authoring_document.gd")

func make_pickup(document: Dictionary, id: String) -> Dictionary:
	var checked = Document.new().validate(document)
	if not checked.ok: return checked
	var copy = document.duplicate(true)
	for entity in copy.get("entities", []):
		if entity.id == id:
			entity.type = "pickup"
			entity.collider = entity.get("collider", {"type": "box", "size": [1, 1, 1]})
			return _result(copy)
	return {"ok": false, "error": "Unknown target"}

func bind_behavior(document: Dictionary, id: String, event: String, actions: Array) -> Dictionary:
	var checked = Document.new().validate(document)
	if not checked.ok: return checked
	if not preload("res://scripts/worlds/world_data.gd").bounded(actions): return {"ok": false, "error": "Oversized behavior actions"}
	for action in actions:
		if not action is Dictionary: return {"ok": false, "error": "Action must be a dictionary"}
	var copy = document.duplicate(true)
	_infer_capabilities(actions, copy.capabilities)
	copy.behaviors.append({"entity": id, "event": event, "actions": actions.duplicate(true)})
	return _result(copy)

func duplicate_entity(document: Dictionary, id: String) -> Dictionary:
	var checked = Document.new().validate(document)
	if not checked.ok: return checked
	var copy = document.duplicate(true)
	for entity in document.entities:
		if entity.id == id:
			if entity.type == "spawn": return {"ok": false, "error": "Only one spawn is allowed"}
			var duplicate = entity.duplicate(true)
			duplicate.id = Crypto.new().generate_random_bytes(16).hex_encode()
			duplicate.name += " copy"
			copy.entities.append(duplicate)
			for behavior in document.behaviors:
				if behavior.entity != id: continue
				var binding = behavior.duplicate(true)
				binding.entity = duplicate.id
				_retarget_actions(binding.actions, id, duplicate.id)
				copy.behaviors.append(binding)
			var result = _result(copy)
			result.entity_id = duplicate.id
			return result
	return {"ok": false, "error": "Unknown target"}

func _infer_capabilities(actions: Array, capabilities: Array) -> void:
	for action in actions:
		if not action is Dictionary: continue
		var capability = ""
		match action.get("op"):
			"command": capability = action.get("capability", "")
			"checkpoint": capability = "player.checkpoint"
			"save_set", "save_add", "save_delete", "if_saved": capability = "storage.local"
		if capability in ["entity.visual", "storage.local", "player.checkpoint"] and capability not in capabilities:
			capabilities.append(capability)
		for field in ["body", "then", "else"]:
			if action.get(field) is Array: _infer_capabilities(action[field], capabilities)

func _retarget_actions(actions: Array, old_id: String, new_id: String) -> void:
	for action in actions:
		if action.get("entity") == old_id: action.entity = new_id
		for field in ["body", "then", "else"]:
			if action.get(field) is Array: _retarget_actions(action[field], old_id, new_id)

func _result(document: Dictionary) -> Dictionary:
	var result = Document.new().validate(document)
	if result.ok: result.document = document
	return result

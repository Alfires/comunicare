extends RefCounted
func transform_operation(mode: String, entity: String, position: Array, rotation: Array, scale: Array, blocked: bool) -> Dictionary:
	if blocked or mode not in ["desktop", "vr"] or entity.is_empty(): return {"ok": false}
	for vector in [position, rotation, scale]:
		if vector.size() != 3: return {"ok": false}
		for value in vector:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(value) > 10000: return {"ok": false}
	for value in scale:
		if value <= 0: return {"ok": false}
	# First authoring schema supports translation only. Reject unsupported changes.
	if rotation != [0, 0, 0] or scale != [1, 1, 1]: return {"ok": false, "error": "Rotation/scale authoring not supported yet"}
	return {"ok": true, "operation": {"op": "set_transform", "entity": entity, "position": position.duplicate()}}

extends RefCounted
const MAX_ENTRIES = 256

static func catalog(bytes: PackedByteArray) -> Dictionary:
	var decoded = DecodeResult.json_value(bytes, 2 * 1024 * 1024)
	if not decoded.ok or not decoded.value is Array or decoded.value.size() > MAX_ENTRIES: return {"ok": false}
	var result: Array = []
	for value in decoded.value:
		if not value is Dictionary or not WorldAddress.is_valid(value.get("url")): return {"ok": false}
		if not value.get("name", "") is String or value.get("name", "").length() > 128: return {"ok": false}
		if not value.get("description", "") is String or value.get("description", "").length() > 2048: return {"ok": false}
		result.append({"url": value.url, "name": value.get("name", value.url), "description": value.get("description", "")})
	return {"ok": true, "value": result}

static func summaries(sessions: Array) -> Dictionary:
	var result: Dictionary = {}
	if sessions.size() > MAX_ENTRIES: return result
	for value in sessions:
		if not value is Dictionary or value.get("mode", -1) != PacketInfo.MODE.PUBLIC: continue
		var id = value.get("session_id")
		if not id is String or id.is_empty() or id.length() > 128 or result.has(id) or not WorldAddress.is_valid(value.get("world_url")): continue
		if not InstanceState.integer(value.get("player_count", 0), 0, 256): continue
		if not value.get("name", "Public instance") is String or value.get("name", "").length() > 128: continue
		if not value.get("description", "") is String or value.get("description", "").length() > 2048: continue
		result[id] = {"session_id": id, "world_url": value.world_url, "name": value.get("name", "Public instance"),
			"description": value.get("description", ""), "player_count": int(value.get("player_count", 0))}
	return result

static func classify_query(text: String) -> String:
	if WorldAddress.is_valid(text): return "url"
	if text.length() == 5:
		var code := true
		for character in text:
			if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789": code = false
		if code: return "code"
	return "filter"

extends RefCounted
## Pure bounded configuration/protocol guards; no identity verification here.

static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func identity(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if not character in "0123456789abcdef": return false
	return true

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func text(value: Variant, maximum: int, empty: bool = false) -> bool:
	if not value is String or value.length() > maximum or (not empty and value.strip_edges().is_empty()): return false
	for character in value:
		if character.unicode_at(0) < 32: return false
	return true

static func host(value: Variant) -> bool:
	if not text(value, 253) or value != value.strip_edges(): return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:_%": return false
	return true

static func keys(value: Dictionary, allowed: Array) -> bool:
	for key in value:
		if not key in allowed: return false
	return true

static func endpoint(hostname: String, port: int) -> String:
	return hostname.to_lower() + ":" + str(port)

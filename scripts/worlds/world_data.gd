extends RefCounted
## Shared pure-data guards. Never deserialize objects or call package methods.

static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "commands": []}

static func safe_path(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 512:
		return false
	if value.is_absolute_path() or ":" in value or "\\" in value or value.ends_with("/"):
		return false
	for part in value.split("/"):
		if part in ["", ".", ".."] or part.strip_edges() != part:
			return false
	for character in value:
		if character.unicode_at(0) < 32 or character.unicode_at(0) > 126:
			return false
	return true

static func bounded(value: Variant, depth: int = 0, budget: Array = []) -> bool:
	if budget.is_empty(): budget = [16384]
	budget[0] -= 1
	if budget[0] < 0 or depth > 32:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return value.length() <= 4096
		TYPE_ARRAY:
			if value.size() > 4096: return false
			for child in value:
				if not bounded(child, depth + 1, budget): return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 1024: return false
			for key in value:
				if not (key is String or key is StringName) or key.length() > 512 or not bounded(value[key], depth + 1, budget): return false
			return true
	return false

static func keys_only(value: Dictionary, allowed: Array) -> bool:
	for key in value:
		if not key in allowed: return false
	return true

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

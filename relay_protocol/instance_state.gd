class_name InstanceState
extends RefCounted

static func integer(value: Variant, minimum: int = 0, maximum: int = 9007199254740991) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value >= minimum and value <= maximum and value == int(value)

static func valid_metadata(value: Dictionary) -> bool:
	if not (integer(value.get("mode"), 0, 4) and value.get("name") is String \
		and not value.name.strip_edges().is_empty() and value.name.length() <= 128 \
		and value.get("description") is String and value.description.length() <= 2048):
		return false
	for field in ["name", "description"]:
		for character in value[field]:
			var code = character.unicode_at(0)
			if code == 127 or (code < 32 and not (field == "description" and code == 10)):
				return false
	return true

static func valid_fingerprint(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true

static func valid(value: Dictionary) -> bool:
	if not valid_metadata(value) or not WorldAddress.is_valid(value.get("world_url")) \
		or not value.get("session_id") is String or value.session_id.is_empty() \
		or value.session_id.length() > 128 or not integer(value.get("revision")) \
		or not value.get("members") is Array or value.members.is_empty() or value.members.size() > 256:
		return false
	var identities := {}
	var ids := {}
	for member in value.members:
		if not member is Dictionary or not integer(member.get("peer_id"), 0, 255) \
			or not valid_fingerprint(member.get("fingerprint")) or member.get("role") not in ["admin", "member"] \
			or identities.has(member.fingerprint) or ids.has(member.peer_id):
			return false
		identities[member.fingerprint] = true
		ids[member.peer_id] = true
	return true

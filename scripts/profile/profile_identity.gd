extends RefCounted

static func digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()

static func canonical_key(text: String) -> String:
	if text.length() > 8192 or not text.begins_with("-----BEGIN PUBLIC KEY-----"):
		return ""
	var key = CryptoKey.new()
	if key.load_from_string(text, true) != OK:
		return ""
	return key.save_to_string(true)

static func fingerprint(text: String) -> String:
	var canonical = canonical_key(text)
	return "" if canonical.is_empty() else digest(canonical.to_utf8_buffer()).hex_encode()

static func defaults() -> Dictionary:
	return {"profile.username": "User", "profile.description": "", "profile.icon_source": "",
		"profile.avatar_url": "https://raw.githubusercontent.com/V-Sekai/godot-vrm/refs/heads/master/vrm_samples/AliciaSolid_vrm-0.51.vrm"}

static func valid_url(value: Variant, allow_empty: bool = false) -> bool:
	if not value is String or value.length() > 4096:
		return false
	if value.is_empty():
		return allow_empty
	if not (value.begins_with("https://") or value.begins_with("http://")):
		return false
	var host = value.split("://")[1].split("/")[0].split("?")[0].split("#")[0]
	if host.is_empty() or "@" in host:
		return false
	for character in value:
		if character.unicode_at(0) <= 32:
			return false
	return true

static func normalized(fields: Dictionary) -> Dictionary:
	var result = defaults()
	for id in result:
		if not fields.get(id) is String:
			return {}
		result[id] = fields[id]
	result["profile.username"] = result["profile.username"].strip_edges()
	if result["profile.username"].is_empty() or result["profile.username"].length() > 128 \
		or result["profile.description"].length() > 1024:
		return {}
	for id in ["profile.username", "profile.description"]:
		for character in result[id]:
			var code = character.unicode_at(0)
			if (code < 32 and not (id == "profile.description" and code == 10)) or code == 127:
				return {}
	if not valid_url(result["profile.avatar_url"]) or not valid_url(result["profile.icon_source"], true):
		return {}
	return result

static func signed_bytes(public_key: String, revision: int, fields: Dictionary) -> PackedByteArray:
	# Fixed field order, independent of dictionary/JSON ordering.
	return JSON.stringify(["comunicare/profile/v1", public_key, revision,
		fields.get("profile.username"), fields.get("profile.description"),
		fields.get("profile.icon_source"), fields.get("profile.avatar_url")]).to_utf8_buffer()

static func verify_profile(profile: Dictionary) -> bool:
	var fields = normalized(profile)
	for id in fields:
		if fields[id] != profile.get(id):
			return false
	if fields.is_empty() or not profile.get("public_key") is String \
		or not (profile.get("revision") is int or profile.get("revision") is float) \
		or not profile.get("signature") is String:
		return false
	var revision = profile.revision
	if revision < 0 or revision != int(revision) or revision > 9007199254740991:
		return false
	var canonical = canonical_key(profile.public_key)
	if canonical.is_empty() or canonical != profile.public_key:
		return false
	var key = CryptoKey.new()
	key.load_from_string(canonical, true)
	var signature = Marshalls.base64_to_raw(profile.signature)
	if signature.is_empty() or signature.size() > 1024:
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256,
		digest(signed_bytes(canonical, int(revision), fields)),
		signature, key)

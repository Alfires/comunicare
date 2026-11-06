extends RefCounted
const Policy = preload("res://scripts/discovery/avatars/request_policy.gd")
var sources: Dictionary = {}
var secrets: Dictionary = {}
var policy = Policy.new()

func add_source(value: Dictionary) -> bool:
	var id = value.get("id")
	if not id is String or id.strip_edges().is_empty() or id.length() > 80 or sources.has(id) or sources.size() >= 64: return false
	if value.get("kind") not in ["builtin", "custom"] or not policy.valid_url(str(value.get("base_url", ""))): return false
	var auth = value.get("auth", "none")
	if auth not in ["none", "bearer", "api_key", "oauth"] or (value.kind == "builtin" and auth != "none"): return false
	if value.kind == "custom" and value.get("adapter", "catalog") != "catalog": return false
	if value.get("adapter", "catalog") not in ["catalog", "osa", "osa-neon", "vox"]: return false
	if not value.get("enabled", true) is bool: return false
	sources[id] = {"id": id, "kind": value.kind, "base_url": value.base_url, "auth": auth,
		"name": str(value.get("name", id)).left(100), "adapter": str(value.get("adapter", "catalog")), "enabled": value.get("enabled", true) == true}
	if auth == "oauth":
		var config = value.get("oauth", {})
		if not config is Dictionary or not policy.valid_url(str(config.get("authorization_url", ""))) or not policy.valid_url(str(config.get("token_url", ""))) or not config.get("client_id") is String or config.client_id.strip_edges().is_empty() or config.client_id.length() > 256:
			sources.erase(id)
			return false
		sources[id].oauth = {"authorization_url": config.authorization_url, "token_url": config.token_url, "client_id": str(config.client_id).left(256), "scope": str(config.get("scope", "")).left(512)}
	return true

func set_credentials(id: String, value: Dictionary) -> bool:
	if not sources.has(id) or sources[id].kind != "custom" or sources[id].auth == "none": return false
	var token = value.get("token", "")
	if not token is String or token.is_empty() or "\n" in token or "\r" in token or token.length() > 4096: return false
	for index in token.length():
		if token.unicode_at(index) < 32 or token.unicode_at(index) == 127: return false
	secrets[id] = {"token": token, "memory_only": true}
	return true

func get_credentials(id: String) -> Dictionary:
	return secrets.get(id, {}).duplicate()

func remove_source(id: String):
	secrets.erase(id)
	sources.erase(id)

func export_configuration() -> Array:
	return sources.values().duplicate(true)

func clear_credentials():
	secrets.clear()

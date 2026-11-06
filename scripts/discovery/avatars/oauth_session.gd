extends RefCounted
## OAuth public-client PKCE session; endpoint configuration is user supplied.
var verifier := ""
var state := ""
var expires := 0
var redirect_uri := ""
var session_config: Dictionary = {}
var policy = preload("res://scripts/discovery/avatars/request_policy.gd").new()

func _base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")

func begin(config: Dictionary) -> String:
	clear()
	if not policy.valid_url(str(config.get("authorization_url", ""))) or not policy.valid_url(str(config.get("token_url", ""))): return ""
	if str(config.get("client_id", "")).is_empty(): return ""
	for pair in str(config.authorization_url).get_slice("?", 1).split("&"):
		if pair.get_slice("=", 0).uri_decode() in ["state", "client_id", "redirect_uri", "response_type", "code_challenge", "code_challenge_method", "scope"]: return ""
	redirect_uri = str(config.get("redirect_uri", ""))
	if not redirect_uri.begins_with("http://127.0.0.1:") or not policy.valid_url(redirect_uri, true) or "?" in redirect_uri: return ""
	if redirect_uri.trim_prefix("http://").find("/") < 0: return ""
	session_config = {"client_id": config.client_id, "token_url": config.token_url, "authorization_url": config.authorization_url}
	var crypto = Crypto.new()
	verifier = _base64url(crypto.generate_random_bytes(32))
	state = _base64url(crypto.generate_random_bytes(32))
	expires = Time.get_ticks_msec() + 180000
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(verifier.to_utf8_buffer())
	var query = {"response_type": "code", "client_id": config.client_id, "redirect_uri": redirect_uri, "state": state,
		"code_challenge_method": "S256", "code_challenge": _base64url(hash.finish()), "scope": str(config.get("scope", ""))}
	var fields: Array[String] = []
	for key in query: fields.append(str(key).uri_encode() + "=" + str(query[key]).uri_encode())
	return config.authorization_url + ("&" if "?" in config.authorization_url else "?") + "&".join(fields)

func accept_callback(url: String, config: Dictionary) -> Dictionary:
	if state.is_empty() or Time.get_ticks_msec() > expires or url.length() > 8192: clear(); return {}
	for key in session_config:
		if config.get(key) != session_config[key]: return {}
	if url.get_slice("?", 0) != redirect_uri or "#" in url: return {}
	var params := {}
	for pair in url.get_slice("?", 1).split("&"):
		var separator = pair.find("=")
		if separator < 0: return {}
		var key = pair.left(separator).replace("+", " ").uri_decode()
		if params.has(key): return {}
		params[key] = pair.substr(separator + 1).replace("+", " ").uri_decode()
	if params.get("state") != state or params.has("error") or str(params.get("code", "")).strip_edges().is_empty(): return {}
	var result = {"grant_type": "authorization_code", "code": params.code, "client_id": config.client_id, "redirect_uri": redirect_uri, "code_verifier": verifier}
	clear() # one use only
	return result

func clear():
	session_config.clear()
	verifier = ""
	state = ""
	redirect_uri = ""
	expires = 0

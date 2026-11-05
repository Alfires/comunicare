extends RefCounted
## No credential-bearing URLs; custom credentials are exact-origin, memory-only.
func origin(url: String) -> String:
	return url.get_slice("://", 0).to_lower() + "://" + url.get_slice("://", 1).get_slice("/", 0).get_slice("?", 0).to_lower()

func valid_url(url: String, loopback: bool = false) -> bool:
	if url.length() > 4096 or " " in url or "\\" in url or "\n" in url or "\r" in url or "#" in url: return false
	if not url.begins_with("https://") and not (loopback and url.begins_with("http://127.0.0.1:")): return false
	var authority = url.get_slice("://", 1).get_slice("/", 0).get_slice("?", 0)
	if authority.is_empty() or "@" in authority: return false
	for parameter in url.get_slice("?", 1).split("&"):
		if parameter.get_slice("=", 0).uri_decode().to_lower() in ["token", "api_key", "apikey", "access_token", "signature", "sig", "key"]: return false
	return true

func prepare_request(source: Dictionary, target_url: String, credentials: Dictionary, loopback: bool = false) -> Dictionary:
	if not valid_url(target_url, loopback): return {}
	var headers = PackedStringArray(["Accept: application/json"])
	if source.get("kind") == "custom" and source.get("auth", "none") != "none":
		if origin(target_url) != origin(str(source.get("base_url", ""))): return {}
		var token = str(credentials.get("token", ""))
		if token.is_empty() or token.length() > 4096 or "\n" in token or "\r" in token: return {}
		if source.auth in ["bearer", "oauth"]: headers.append("Authorization: Bearer " + token)
		elif source.auth == "api_key": headers.append("X-API-Key: " + token)
		else: return {}
	return {"url": target_url, "headers": headers}

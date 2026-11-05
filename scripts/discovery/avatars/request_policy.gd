extends RefCounted
## No credential-bearing URLs; custom credentials are exact-origin, memory-only.
func origin(url: String) -> String:
	return url.get_slice("://", 0).to_lower() + "://" + url.get_slice("://", 1).get_slice("/", 0).get_slice("?", 0).to_lower()

func valid_url(url: String, loopback: bool = false) -> bool:
	if url.length() > 4096 or " " in url or "\\" in url or "\n" in url or "\r" in url or "#" in url: return false
	for index in url.length():
		if url.unicode_at(index) < 32 or url.unicode_at(index) == 127: return false
	if not url.begins_with("https://") and not (loopback and url.begins_with("http://127.0.0.1:")): return false
	var authority = url.get_slice("://", 1).get_slice("/", 0).get_slice("?", 0)
	if authority.is_empty() or "@" in authority: return false
	var host = authority
	var port := ""
	if authority.begins_with("["):
		var end = authority.find("]")
		if end < 2: return false
		host = authority.substr(1, end - 1)
		if not host.is_valid_ip_address(): return false
		var suffix = authority.substr(end + 1)
		if not suffix.is_empty():
			if not suffix.begins_with(":"): return false
			port = suffix.substr(1)
			if port.is_empty(): return false
	else:
		if authority.count(":") > 1: return false
		if ":" in authority:
			host = authority.get_slice(":", 0)
			port = authority.get_slice(":", 1)
			if port.is_empty(): return false
		if host.is_empty() or "%" in host or "[" in host or "]" in host: return false
	if not port.is_empty() and (not port.is_valid_int() or int(port) < 1 or int(port) > 65535): return false
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

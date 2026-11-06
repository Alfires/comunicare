extends Node
signal download_progress(received: int, total: int)

func _process(_delta: float):
	for request in requests:
		if is_instance_valid(request): download_progress.emit(request.get_downloaded_bytes(), request.get_body_size())
const Policy = preload("res://scripts/discovery/avatars/request_policy.gd")
const OSA = "https://raw.githubusercontent.com/ToxSam/open-source-avatars/main/data/"
const VOX = "https://raw.githubusercontent.com/SanHsien/voxavatar/main/public/assets/"
var source: Dictionary = {}
var options: Dictionary = {}
var credentials: Dictionary = {}
var generation := 0
var requests: Array = []
var policy = Policy.new()
var catalogs: Dictionary = {}
var retry_at: Dictionary = {}
const CATALOG_TTL_MSEC = 300000

func configure(value: Dictionary, transport_options: Dictionary = {}):
	cancel()
	source = value.duplicate(true)
	options = transport_options.duplicate()
	credentials = {}

func cancel():
	generation += 1
	for request in requests.duplicate():
		if is_instance_valid(request):
			request.cancel_request()
			request.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())
	credentials.clear()

func request_bytes(url: String, limit: int = 4 * 1024 * 1024, redirects: int = 0) -> Dictionary:
	var prepared = policy.prepare_request(source, url, credentials, options.get("allow_loopback_http", false))
	if prepared.is_empty(): return {"error": "Unsafe URL, unsupported authentication or missing credential"}
	if Time.get_ticks_msec() < retry_at.get(policy.origin(url), 0): return {"error": "Provider rate limited; retry later"}
	if requests.size() >= 4: return {"error": "Too many pending requests"}
	var ticket = generation
	var request = HTTPRequest.new()
	request.timeout = 20
	request.body_size_limit = limit
	request.max_redirects = 0
	add_child(request)
	requests.append(request)
	var response: Array = []
	if request.request(url, prepared.headers) == OK: response = await request.request_completed
	requests.erase(request)
	request.queue_free()
	await get_tree().process_frame
	if ticket != generation: return {"error": "Cancelled"}
	if response.size() != 4: return {"error": "Provider request failed"}
	var code = int(response[1])
	var no_store := false
	for header in response[2]:
		if header.to_lower().begins_with("cache-control:") and "no-store" in header.to_lower(): no_store = true
	if code in [301, 302, 303, 307, 308] and redirects < 3:
		var location := ""
		for header in response[2]:
			if header.to_lower().begins_with("location:"): location = header.substr(9).strip_edges()
		location = _redirect_url(url, location)
		# Authenticated custom sources may never redirect to a different origin.
		var redirected = await request_bytes(location, limit, redirects + 1)
		if no_store and redirected.has("bytes"): redirected.no_store = true
		return redirected
	if code == 429:
		var seconds := 60
		for header in response[2]:
			if header.to_lower().begins_with("retry-after:") and header.substr(12).strip_edges().is_valid_int(): seconds = clampi(int(header.substr(12)), 1, 900)
		retry_at[policy.origin(url)] = Time.get_ticks_msec() + seconds * 1000
		return {"error": "Provider rate limited; retry later"}
	if code != 200: return {"error": "Provider returned HTTP %s (login is never requested for built-ins)" % code}
	if response[0] != HTTPRequest.RESULT_SUCCESS: return {"error": "Provider transfer failed or exceeded size limit"}
	return {"bytes": response[3], "no_store": no_store}

func _redirect_url(base: String, location: String) -> String:
	if location.is_empty(): return ""
	if location.begins_with("https://") or location.begins_with("http://"): return location
	if location.begins_with("//"): return base.get_slice("://", 0) + ":" + location
	if location.begins_with("/"): return policy.origin(base) + location
	if location.begins_with("?"): return base.get_slice("?", 0) + location
	# A relative path may not smuggle a new scheme; policy validates the result.
	if ":" in location.get_slice("/", 0): return ""
	var address = base.get_slice("?", 0)
	var origin = policy.origin(address)
	var path = address.substr(origin.length())
	if path.is_empty(): path = "/"
	return origin + (path.get_base_dir() + "/" + location).simplify_path()

func _json(url: String) -> Dictionary:
	var response = await request_bytes(url)
	if response.has("error"): return response
	var text: String = response.bytes.get_string_from_utf8()
	# Bound nesting before JSON parsing, respecting quoted/escaped text.
	var depth := 0
	var quoted := false
	var escape := false
	for c in text:
		if quoted:
			if escape: escape = false
			elif c == "\\": escape = true
			elif c == "\"": quoted = false
		elif c == "\"": quoted = true
		elif c in ["{", "["]:
			depth += 1
			if depth > 32: return {"error": "Catalog nesting limit exceeded"}
		elif c in ["}", "]"]: depth -= 1
	var parser = JSON.new()
	if parser.parse(text) != OK: return {"error": "Invalid provider JSON"}
	return {"data": parser.data}

func search(query: Dictionary) -> Dictionary:
	var ticket = generation
	if source.get("adapter", "catalog") == "catalog":
		var endpoint: String = source.base_url
		var address = endpoint.get_slice("?", 0)
		if address.trim_prefix("https://").trim_prefix("http://").find("/") < 0:
			endpoint = address + "/" + ("?" + endpoint.get_slice("?", 1) if "?" in endpoint else "")
		var separator = "&" if "?" in endpoint else "?"
		var result = await _json(endpoint + separator + "query=" + str(query.get("query", "")).left(200).uri_encode() + "&type=" + str(query.get("type", "all")).uri_encode() + "&cursor=" + str(query.get("cursor", "")).left(512).uri_encode())
		if result.has("error"): return result
		if not result.data is Dictionary or result.data.get("schema") != 1 or not result.data.get("items") is Array or result.data.items.size() > 200: return {"error": "Unsupported catalog schema"}
		var normalized: Array = []
		var seen := {}
		for item in result.data.items:
			if not item is Dictionary or not item.get("id") is String or item.id.is_empty() or item.id.length() > 200: continue
			if seen.has(item.id) or item.get("type") not in ["avatar", "animation"]: continue
			seen[item.id] = true
			var record = {}
			for field in ["id", "title", "type", "author", "format", "license", "category", "page_url", "thumbnail_url", "download_url", "sha256"]:
				if item.get(field, "") is String: record[field] = item.get(field, "").left(4096 if field.ends_with("url") else 200)
			record.compatibility = "unknown" # A remote catalog can never self-certify importer validation.
			var consent = item.get("redistribution", false)
			record.redistribution = consent is bool and consent
			record.tags = []
			if item.get("tags") is Array:
				for tag in item.tags.slice(0, 20):
					if tag is String: record.tags.append(tag.left(80))
			if item.get("loop") is bool: record.loop = item.loop
			normalized.append(record)
		var next = result.data.get("next_cursor", "")
		return {"items": preload("res://scripts/discovery/avatars/catalog_filters.gd").new().apply(normalized, query), "next_cursor": next.left(512) if next is String else "", "request_received": result.data.get("request_received", {}), "scope": "Advanced filters apply to this fetched provider page"}
	var key: String = source.id
	if catalogs.has(key) and catalogs[key] is Dictionary and Time.get_ticks_msec() - catalogs[key].at > CATALOG_TTL_MSEC: catalogs.erase(key)
	if not catalogs.has(key):
		var result = await _json(source.base_url)
		if result.has("error"): return result
		var records: Array = []
		if source.adapter in ["osa", "osa-neon"]:
			if not result.data is Array: return {"error": "Invalid avatar catalog"}
			for item in result.data:
				if not item is Dictionary or not item.get("is_public", false) or item.get("is_draft", false): continue
				if source.adapter == "osa-neon":
					var verified = {
						"https://raw.githubusercontent.com/neonglitch86/vrm/main/SBW_86v2.vrm": "10b1feceb1734188e5295d644300a25ed623fc4af9679764bb57748e650380c3",
						"https://raw.githubusercontent.com/neonglitch86/vrm/main/GG_1.vrm": "fc84fc35ad78f8010f688ed2ae9a12045a9ae814429e70bd51f9fe0e4e2b6ea7"}
					if not verified.has(item.get("model_file_url", "")): continue
					records.append({"id": str(item.get("id", "")).left(100), "title": str(item.get("name", "Avatar")).left(200), "type": "avatar", "format": "vrm", "author": "NeonGlitch86", "license": "CC0-1.0", "redistribution": true, "compatibility": "unknown", "download_url": item.model_file_url, "thumbnail_url": item.get("thumbnail_url", ""), "page_url": "https://opensourceavatars.com", "category": "humanoid", "sha256": verified[item.model_file_url]})
					continue
				records.append({"id": str(item.get("id", "")).left(100), "title": str(item.get("name", "Avatar")).left(200), "type": "avatar", "format": "vrm", "author": "Polygonal Mind", "license": "CC0-1.0", "redistribution": true, "compatibility": "unknown", "download_url": item.get("model_file_url", ""), "thumbnail_url": item.get("thumbnail_url", ""), "page_url": "https://opensourceavatars.com", "category": "humanoid"})
		elif source.adapter == "vox":
			if not result.data is Dictionary or not result.data.get("assets") is Array: return {"error": "Invalid motion manifest"}
			for item in result.data.assets:
				if item.get("role") != "animation" or item.get("license") != "CC0 1.0 Universal": continue
				var path = str(item.get("path", ""))
				if not path.begins_with("animations/") or ".." in path or not path.ends_with(".vrma"): continue
				records.append({"id": path, "title": path.get_file().get_basename(), "type": "animation", "format": "vrma", "author": str(item.get("creator", "")).left(200), "license": "CC0-1.0", "redistribution": true, "compatibility": "unknown", "download_url": VOX + path, "page_url": item.get("source", ""), "sha256": item.get("sha256", ""), "category": "emotes"})
		if ticket != generation: return {"error": "Cancelled"}
		catalogs[key] = {"records": records.slice(0, 1000), "at": Time.get_ticks_msec()}
	var cached = catalogs[key].records if catalogs[key] is Dictionary else catalogs[key]
	var filtered: Array = preload("res://scripts/discovery/avatars/catalog_filters.gd").new().apply(cached, query)
	var start = maxi(0, int(query.get("cursor", "0")))
	return {"items": filtered.slice(start, start + 24), "next_cursor": str(start + 24) if start + 24 < filtered.size() else "", "scope": "Search over fetched public catalog"}

func _exit_tree():
	cancel()

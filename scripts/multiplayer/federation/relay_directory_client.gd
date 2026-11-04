extends RefCounted
## Concurrent certificate-verified anonymous directory queries. No account access.
const Link = preload("res://scripts/multiplayer/federation/secure_relay_link.gd")
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
const Directory = preload("res://scripts/multiplayer/federation/federation_directory.gd")
var links: Dictionary = {}
var trusted: Dictionary = {}
var blocked_ids: Array = []
var blocked_endpoints: Array = []
var last_error := ""
signal changed

func add_trusted(host: String, port: int, id: String, certificate: X509Certificate, common_name: String = "comunicare-relay") -> bool:
	if not Guard.host(host) or port < 1 or port > 65535 or not Guard.identity(id) or certificate == null or trusted.size() >= 64: return false
	trusted[id] = {"host": host, "port": port, "certificate": certificate, "common_name": common_name}
	return true

func query(id: String) -> bool:
	if not trusted.has(id) or id in blocked_ids: return false
	var target: Dictionary = trusted[id]
	if Guard.endpoint(target.host, target.port) in blocked_endpoints: return false
	if links.has(id):
		links[id].query_at = 0
		return true
	if links.size() >= 4: return false
	var link = Link.new()
	if not link.connect_to(target.host, target.port, target.certificate, target.common_name):
		last_error = link.last_error
		return false
	links[id] = {"link": link, "nonce": "", "query_at": 0, "expires": 0, "boot": "", "instances": [], "started": Time.get_ticks_msec()}
	return true

func set_blocks(ids: Array, endpoints: Array):
	blocked_ids = ids.duplicate()
	blocked_endpoints = endpoints.duplicate()
	for id in links.keys():
		var target: Dictionary = trusted[id]
		if id in blocked_ids or Guard.endpoint(target.host, target.port) in blocked_endpoints:
			links[id].link.close()
			links.erase(id)
	# Also suppress blocked distant origins advertised through allowed links.
	changed.emit()

func poll():
	var now = Time.get_ticks_msec()
	for id in links.keys():
		var record: Dictionary = links[id]
		record.link.poll()
		if not record.link.last_error.is_empty():
			last_error = record.link.last_error
			record.link.close()
			links.erase(id)
			changed.emit()
			continue
		if not record.link.connected(): continue
		if now >= record.query_at:
			record.query_at = now + 5000
			record.nonce = Crypto.new().generate_random_bytes(16).hex_encode()
			record.link.send({"op": "public_query", "nonce": record.nonce})
		for message in record.link.drain():
			if message.get("op") != "public_directory" or message.get("relay_id") != id or message.get("nonce") != record.nonce \
				or not Guard.text(message.get("boot_id"), 128) or not message.get("instances") is Array or message.instances.size() > 256: continue
			var valid = true
			for summary in message.instances:
				if not summary is Dictionary or not Guard.identity(summary.get("origin_relay_id")) or not Guard.text(summary.get("origin_boot_id"), 128) \
					or not Directory.valid_summary(summary, summary.origin_relay_id, summary.origin_boot_id): valid = false; break
			if not valid: continue
			record.instances = message.instances.duplicate(true)
			record.boot = message.boot_id
			record.expires = now + 15000
			changed.emit()
		if record.expires > 0 and now >= record.expires:
			record.instances.clear()
			record.expires = 0
			changed.emit()

func instances() -> Array:
	var result: Dictionary = {}
	for record in links.values():
		for summary in record.instances:
			if summary.origin_relay_id in blocked_ids: continue
			var key = summary.origin_relay_id + ":" + summary.origin_boot_id + ":" + summary.instance_id
			result[key] = summary.duplicate(true)
	return result.values()

func stop():
	for record in links.values(): record.link.close()
	links.clear()
	changed.emit()

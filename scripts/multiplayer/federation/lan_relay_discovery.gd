extends RefCounted
## Datagram-to-candidate state only; verified_directory is a trusted verifier boundary.
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
const Directory = preload("res://scripts/multiplayer/federation/federation_directory.gd")
var enabled := true
var maximum := 64
var ttl := 10000
var blocks: Array = []
var records: Dictionary = {}

func configure(limits: Dictionary, blocked_ids: Array):
	enabled = limits.get("enabled", true) == true
	maximum = clampi(int(limits.get("max_candidates", 64)), 1, 64)
	ttl = clampi(int(limits.get("ttl_ms", 10000)), 1000, 15000)
	blocks = blocked_ids.duplicate()
	records.clear()

static func local_address(address: String) -> bool:
	if not address.is_valid_ip_address(): return false
	if ":" in address:
		return address == "::1" or address.to_lower().begins_with("fe80:") or address.to_lower().begins_with("fc") or address.to_lower().begins_with("fd")
	var parts = address.split(".")
	return parts[0] in ["10", "127"] or (parts[0] == "192" and parts[1] == "168") \
		or (parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31) or (parts[0] == "169" and parts[1] == "254")

func observe(bytes: PackedByteArray, source_ip: String, now: int) -> Dictionary:
	if not enabled or bytes.size() > 1024 or not local_address(source_ip): return Guard.failure("LAN discovery disabled or invalid source/datagram size")
	var parser = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary: return Guard.failure("Malformed LAN advertisement")
	var value: Dictionary = parser.data
	if not Guard.keys(value, ["version", "relay_id", "boot_id", "label", "host", "port"]) or value.get("version") != 1 \
		or not Guard.identity(value.get("relay_id")) or value.relay_id in blocks or not Guard.text(value.get("boot_id"), 128) \
		or not Guard.text(value.get("label"), 128) or not value.get("host") is String or not local_address(value.host) \
		or value.host != source_ip or not Guard.integer(value.get("port"), 1, 65535): return Guard.failure("Unsafe or blocked LAN advertisement")
	if not records.has(value.relay_id) and records.size() >= maximum: return Guard.failure("LAN candidate limit reached")
	var previous: Dictionary = records.get(value.relay_id, {})
	var summaries: Array = previous.get("instances", []) if previous.get("ad", {}).get("boot_id") == value.boot_id else []
	records[value.relay_id] = {"ad": value.duplicate(true), "expires": now + ttl, "instances": summaries}
	return {"ok": true}

func verified_directory(id: String, boot: String, summaries: Array, now: int) -> Dictionary:
	if not enabled or id in blocks or not records.has(id) or records[id].expires <= now or records[id].ad.boot_id != boot or summaries.size() > 256:
		return Guard.failure("LAN directory does not match live candidate")
	for summary in summaries:
		if not Directory.valid_summary(summary, id, boot): return Guard.failure("Invalid LAN public instance")
	records[id].instances = summaries.duplicate(true)
	return {"ok": true}

func candidates() -> Array:
	var result: Array = []
	for value in records.values(): result.append(value.ad.duplicate(true))
	return result

func instances() -> Array:
	var result: Array = []
	for value in records.values(): result.append_array(value.instances.duplicate(true))
	return result

func expire(now: int):
	for id in records.keys():
		if now >= records[id].expires: records.erase(id)

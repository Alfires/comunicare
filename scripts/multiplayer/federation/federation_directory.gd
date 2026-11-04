extends RefCounted
## Public summaries only. Caller supplies authenticated provenance, never payload claims.
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
var origins: Dictionary = {}
var blocks: Array = []
var maximum := 1024
var ttl := 15000

func configure(limits: Dictionary, blocked_ids: Array):
	origins.clear()
	blocks = blocked_ids.duplicate()
	maximum = clampi(int(limits.get("max_instances", 1024)), 1, 4096)
	ttl = clampi(int(limits.get("ttl_ms", 15000)), 1000, 30000)

func ingest(origin: String, boot: String, sequence: int, summaries: Array, path: Array, now: int) -> Dictionary:
	if not Guard.identity(origin) or not Guard.text(boot, 128) or origin in blocks or path.is_empty() or path.size() > 4 or path.back() != origin:
		return Guard.failure("Invalid or blocked directory provenance")
	var seen: Dictionary = {}
	for hop in path:
		if not Guard.identity(hop) or hop in blocks or seen.has(hop): return Guard.failure("Blocked/looping directory path")
		seen[hop] = true
	var previous: Dictionary = origins.get(origin, {})
	if previous.get("boot") == boot and sequence <= previous.get("sequence", -1): return Guard.failure("Obsolete directory sequence")
	if summaries.size() > maximum: return Guard.failure("Directory budget exceeded")
	var accepted: Array = []
	var ids: Dictionary = {}
	for value in summaries:
		if not valid_summary(value, origin, boot) or ids.has(value.instance_id): return Guard.failure("Invalid/duplicate public summary")
		ids[value.instance_id] = true
		accepted.append(value.duplicate(true))
	var total = accepted.size()
	for id in origins:
		if id != origin: total += origins[id].values.size()
	if total > maximum or (not origins.has(origin) and origins.size() >= 64): return Guard.failure("Aggregate directory budget exceeded")
	origins[origin] = {"boot": boot, "sequence": sequence, "values": accepted, "path": path.duplicate(), "expires": now + ttl}
	return {"ok": true}

static func valid_summary(value: Variant, origin: String, boot: String) -> bool:
	if not value is Dictionary or not Guard.keys(value, ["origin_relay_id", "origin_boot_id", "instance_id", "world_url", "world_revision", "mode", "name", "description", "player_count"]): return false
	return value.get("origin_relay_id") == origin and value.get("origin_boot_id") == boot \
		and Guard.text(value.get("instance_id"), 128) and value.get("mode") == 0 \
		and Guard.text(value.get("name"), 128) and Guard.text(value.get("description"), 2048, true) \
		and Guard.integer(value.get("player_count"), 1, 256) and Guard.identity(value.get("world_revision")) \
		and Guard.text(value.get("world_url"), 4096) and (value.world_url == "default_wold" or value.world_url.begins_with("https://") or value.world_url.begins_with("http://"))

func snapshot() -> Array:
	var values: Array = []
	for origin in origins.values(): values.append_array(origin.values.duplicate(true))
	return values

func set_blocked(id: String, blocked: bool):
	if blocked and not id in blocks: blocks.append(id)
	elif not blocked: blocks.erase(id)
	if blocked:
		for origin in origins.keys():
			if id == origin or id in origins[origin].path: origins.erase(origin)

func withdraw_origin(id: String, boot: String):
	if origins.get(id, {}).get("boot") == boot: origins.erase(id)

func expire(now: int):
	for id in origins.keys():
		if now >= origins[id].expires: origins.erase(id)

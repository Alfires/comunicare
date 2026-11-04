extends RefCounted
## Deterministic selection policy; actual socket/authentication belongs to caller.
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
var entries: Array = []
var blocks: Array = []
var directories: Array = []
var current := ""
var pending: Dictionary = {}
var position := 0
var serial := 0
var deadline := 0
var timeout := 15000
var maximum := 4

func configure(values: Array, blocked_ids: Array, limits: Dictionary):
	entries = values.duplicate(true)
	blocks = blocked_ids.duplicate()
	directories.clear()
	current = ""
	pending.clear()
	position = 0
	timeout = clampi(int(limits.get("attempt_timeout_ms", 15000)), 1, 30000)
	maximum = clampi(int(limits.get("max_connections", 4)), 1, 4)
	# Serial deliberately survives reconfiguration to reject old completions.

func begin_selection(now: int) -> Dictionary:
	if not pending.is_empty(): return pending.duplicate(true)
	if not current.is_empty(): return {"ok": true, "relay_id": current}
	return _next(now)

func _next(now: int) -> Dictionary:
	while position < entries.size():
		var entry: Dictionary = entries[position]
		position += 1
		if entry.get("relay_id", "") in blocks: continue
		serial += 1
		pending = entry.duplicate(true)
		pending.attempt_id = str(serial)
		deadline = now + timeout
		return pending.duplicate(true)
	pending.clear()
	return Guard.failure("No available allowed relay in saved list")

func complete_attempt(attempt_id: String, outcome: Dictionary, now: int) -> Dictionary:
	if pending.is_empty() or pending.attempt_id != attempt_id or pending.relay_id in blocks: return Guard.failure("Obsolete relay attempt")
	match outcome.get("status"):
		"authenticated":
			if not pending.relay_id.is_empty() and outcome.get("relay_id") != pending.relay_id:
				pending.clear()
				return Guard.failure("Relay identity changed")
			current = str(outcome.get("relay_id", ""))
			pending.clear()
			return {"ok": true}
		"capacity_full", "unavailable", "incompatible":
			pending.clear()
			return _next(now)
		_:
			pending.clear()
			return Guard.failure("Untrusted redirect or authentication/security rejection")

func retry(now: int) -> Dictionary:
	pending.clear()
	position = 0
	return begin_selection(now)

func tick(now: int):
	if not pending.is_empty() and now >= deadline:
		pending.clear()
		_next(now)

func set_blocked(id: String, blocked: bool):
	if blocked and not id in blocks: blocks.append(id)
	elif not blocked: blocks.erase(id)
	if blocked:
		if current == id: current = ""
		directories.erase(id)
		if pending.get("relay_id") == id: pending.clear()

func open_directory(id: String) -> Dictionary:
	if not Guard.identity(id) or id in blocks: return Guard.failure("Relay directory blocked or invalid")
	if id in directories or id == current: return {"ok": true}
	if directories.size() + (0 if current.is_empty() else 1) + (0 if pending.is_empty() else 1) >= maximum: return Guard.failure("Simultaneous relay link limit reached")
	directories.append(id)
	return {"ok": true}

func snapshot() -> Dictionary:
	return {"entries": entries.duplicate(true), "current_relay_id": current, "pending": pending.duplicate(true), "directory_relays": directories.duplicate()}

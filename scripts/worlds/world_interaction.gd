extends RefCounted
## Instance-local exclusive item leases; authoritative sender comes from transport.
const Data = preload("res://scripts/worlds/world_data.gd")
var session := ""
var revision := ""
var members: Dictionary = {}
var items: Dictionary = {}
var sequences: Dictionary = {}

func configure(config: Dictionary):
	session = str(config.get("session_id", ""))
	revision = str(config.get("revision", ""))
	members = config.get("members", {}).duplicate(true)
	items.clear()
	sequences.clear()
	for id in config.get("items", {}):
		if items.size() >= 1024: break
		var entry: Dictionary = config.items[id]
		items[id] = {"pickup": entry.get("pickup", false) == true, "max_hands": clampi(int(entry.get("max_hands", 1)), 1, 2),
			"holder": "", "generation": "", "grip": "", "epoch": 0}

func apply(sender: String, event: Variant) -> Dictionary:
	if not event is Dictionary or not Data.bounded(event, 0, [256]): return Data.failure("Invalid item event")
	if not members.has(sender) or event.get("generation") != members[sender] \
		or event.get("session_id") != session or event.get("revision") != revision:
		return Data.failure("Item event is not from a current instance member")
	if not Data.keys_only(event, ["kind", "session_id", "revision", "generation", "entity", "epoch", "sequence", "grip", "input_mode"]):
		return Data.failure("Unknown item event fields")
	if not Data.integer(event.get("sequence"), 1, 2147483647) or event.sequence <= sequences.get(sender, 0) \
		or not items.has(event.get("entity")) or not Data.integer(event.get("epoch"), 0, 2147483646):
		return Data.failure("Unknown item or stale item sequence")
	var item: Dictionary = items[event.entity]
	if not item.pickup or item.epoch != int(event.epoch): return Data.failure("Stale or unavailable item lease")
	match event.get("kind", ""):
		"grab":
			if not item.holder.is_empty() or not event.get("grip") in ["left", "right", "virtual"] \
				or not event.get("input_mode") in ["vr", "desktop"]:
				return Data.failure("Item held or invalid grip")
			item.holder = sender
			item.generation = members[sender]
			item.grip = event.grip
			item.epoch += 1
		"release":
			if item.holder != sender: return Data.failure("Only current holder can release")
			_clear_holder(item)
		_:
			return Data.failure("Unknown item operation")
	sequences[sender] = int(event.sequence)
	return {"ok": true, "item": item.duplicate(true)}

func _clear_holder(item: Dictionary):
	item.holder = ""
	item.generation = ""
	item.grip = ""
	item.epoch += 1

func disconnect_member(id: String, generation: String):
	if members.get(id) != generation: return
	members.erase(id)
	sequences.erase(id)
	for item in items.values():
		if item.holder == id: _clear_holder(item)

func snapshot() -> Dictionary:
	return {"session_id": session, "revision": revision, "items": items.duplicate(true)}

extends RefCounted
## Checked snapshot/tail application. This is not consensus or a network transport.
const Data = preload("res://scripts/worlds/world_data.gd")
var session := ""
var revision := ""
var members: Dictionary = {}
var state: Dictionary = {}
var sequence := -1

func configure(session_id: String, world_revision: String, current_members: Dictionary):
	session = session_id
	revision = world_revision
	members = current_members.duplicate(true)
	state.clear()
	sequence = -1

func _scoped(sender: String, generation: Variant, value: Dictionary) -> bool:
	return members.has(sender) and members[sender] == generation and value.get("session_id") == session and value.get("revision") == revision

func accept_snapshot(sender: String, generation: String, value: Variant) -> Dictionary:
	if not value is Dictionary or not Data.bounded(value, 0, [16384]) or not _scoped(sender, generation, value):
		return Data.failure("Invalid snapshot scope or budget")
	if not Data.keys_only(value, ["session_id", "revision", "sequence", "items"]) or not Data.integer(value.get("sequence"), 0, 2147483647) \
		or value.sequence <= sequence or not value.get("items") is Dictionary or value.items.size() > 1024:
		return Data.failure("Invalid snapshot or rollback")
	for item in value.items.values():
		if not item is Dictionary or not Data.keys_only(item, ["holder", "generation", "grip", "epoch"]) \
			or not Data.integer(item.get("epoch"), 0, 2147483646): return Data.failure("Invalid item snapshot")
		if item.get("holder", "") != "" and (not members.has(item.get("holder")) or members[item.holder] != item.get("generation") \
			or not item.get("grip") in ["left", "right", "virtual"]): return Data.failure("Snapshot names absent holder")
	state = value.duplicate(true)
	sequence = int(value.sequence)
	return {"ok": true}

func apply_event(sender: String, event: Variant) -> Dictionary:
	if not event is Dictionary or not Data.bounded(event, 0, [256]) or not _scoped(sender, event.get("generation"), event) \
		or not Data.integer(event.get("sequence"), 0, 2147483647) or event.sequence != sequence + 1:
		return Data.failure("Invalid event scope, sequence gap or replay")
	if state.is_empty() or not state.items.has(event.get("entity")): return Data.failure("Snapshot required before events")
	var item: Dictionary = state.items[event.entity]
	if event.get("kind") != "release" or item.get("holder") != sender or item.get("epoch") != event.get("epoch"):
		return Data.failure("Invalid lease event")
	item.holder = ""
	item.generation = ""
	item.grip = ""
	item.epoch += 1
	sequence += 1
	state.sequence = sequence
	return {"ok": true}

func snapshot() -> Dictionary:
	return state.duplicate(true)

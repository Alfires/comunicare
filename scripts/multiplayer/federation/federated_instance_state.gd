extends RefCounted
## Origin-only policy state, not proof verification or a transport.
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
var instance: Dictionary = {}
var actors: Dictionary = {}
var items: Dictionary = {}
var sequences: Dictionary = {}
var suspended := false

func configure(destination: Dictionary, allowed_items: Array):
	instance = destination.duplicate(true)
	actors.clear()
	sequences.clear()
	items.clear()
	suspended = false
	for id in allowed_items.slice(0, 256): items[id] = {"holder": {}, "epoch": 0, "grip": ""}

func _actor_key(actor: Dictionary) -> String:
	return str(actor.get("ingress_relay_id", "")) + ":" + str(actor.get("peer_id", "")) + ":" + str(actor.get("generation", ""))

func admit(actor: Dictionary, proof: Dictionary) -> Dictionary:
	if suspended or actors.size() >= 256 or proof.get("verified") != true or proof.get("fresh") != true or proof.get("instance") != instance \
		or not Guard.identity(actor.get("account")) or not Guard.identity(actor.get("ingress_relay_id")) \
		or not Guard.integer(actor.get("peer_id"), 0, 255) or not Guard.text(actor.get("generation"), 128): return Guard.failure("Invalid origin admission proof or actor")
	for current in actors.values():
		if current.account == actor.account: return Guard.failure("Account already admitted")
	actors[_actor_key(actor)] = actor.duplicate(true)
	return {"ok": true}

func apply_item(actor: Dictionary, event: Dictionary) -> Dictionary:
	var key = _actor_key(actor)
	if suspended or actors.get(key) != actor or event.get("instance") != instance or not items.has(event.get("entity")) \
		or not Guard.integer(event.get("sequence"), 1, 2147483647) or event.sequence <= sequences.get(key, 0): return Guard.failure("Invalid actor, instance or event sequence")
	var item: Dictionary = items[event.entity]
	if event.get("epoch") != item.epoch: return Guard.failure("Stale item epoch")
	match event.get("kind"):
		"grab":
			if not item.holder.is_empty() or not event.get("grip") in ["virtual", "left", "right"]: return Guard.failure("Item held or invalid grip")
			item.holder = actor.duplicate(true)
			item.grip = event.grip
		"release":
			if item.holder != actor: return Guard.failure("Only current holder can release")
			item.holder = {}
			item.grip = ""
		_:
			return Guard.failure("Unsupported origin operation")
	item.epoch += 1
	sequences[key] = int(event.sequence)
	return {"ok": true}

func disconnect_actor(actor: Dictionary):
	var key = _actor_key(actor)
	if actors.get(key) != actor: return
	actors.erase(key)
	sequences.erase(key)
	for item in items.values():
		if item.holder == actor:
			item.holder = {}
			item.grip = ""
			item.epoch += 1

func lose_origin():
	suspended = true
	actors.clear()
	sequences.clear()
	for item in items.values():
		item.holder = {}
		item.grip = ""
		item.epoch += 1

func snapshot() -> Dictionary:
	return {"instance": instance.duplicate(true), "actors": actors.values().duplicate(true), "items": items.duplicate(true), "suspended": suspended}

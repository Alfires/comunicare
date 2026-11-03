class_name FriendRouter
extends RefCounted

# Connection-scoped only. No offline mailbox, social database, or file access.
var publications: Dictionary = {}
var grants: Dictionary = {}
var rates: Dictionary = {}
var pending: Dictionary = {}
var sequence := 0
const Identity = preload("res://scripts/profile/profile_identity.gd")

func _send(relay: Node, id: int, value: Dictionary):
	relay._send_account(id, PacketInfo.PACKET_TYPE.SOCIAL_DATA, value)

func _id(relay: Node, public_key: String) -> int:
	for id in relay.key_mapping:
		if relay.key_mapping[id].public_key == public_key:
			return int(id)
	return -1

func mutual(left: int, right: int) -> bool:
	var a: Dictionary = grants.get(left, {}).get(right, {})
	var b: Dictionary = grants.get(right, {}).get(left, {})
	return not a.is_empty() and not b.is_empty() and a.relationship == b.relationship \
		and a.expires > Time.get_ticks_msec() and b.expires > Time.get_ticks_msec()

func handle(relay: Node, actor: int, value: Dictionary):
	if not relay.key_mapping.has(actor):
		return
	var now = Time.get_ticks_msec()
	var rate: Dictionary = rates.get(actor, {"start": now, "count": 0})
	if now - rate.start > 1000:
		rate = {"start": now, "count": 0}
	rate.count += 1
	rates[actor] = rate
	if rate.count > 256:
		return
	var own_key: String = relay.key_mapping[actor].public_key
	match value.get("op"):
		"hello":
			_send(relay, actor, {"op": "capabilities", "version": 1})
		"publish":
			if value.get("status") not in ["online", "offline", "do_not_disturb"] \
				or not InstanceState.valid_fingerprint(value.get("generation")):
				return
			if publications.has(actor) and publications[actor].generation != value.generation:
				_clear_grants(relay, actor, "unavailable")
			publications[actor] = {"status": value.status, "generation": value.generation}
			for target in grants.get(actor, {}):
				_update_pair(relay, actor, int(target))
		"event":
			var event = value.get("event")
			if not event is Dictionary or not FriendEvent.valid(event) or event.actor != own_key:
				return
			var target = _id(relay, event.recipient)
			# Delivery statuses do not distinguish hidden from disconnected accounts.
			if target == -1:
				_send(relay, actor, {"op": "delivery", "event_id": event.event_id, "status": "unavailable"})
				return
			if event.kind in ["decline", "cancel", "revoke"]:
				if grants.get(actor, {}).get(target, {}).get("relationship") == event.relationship_id \
					or grants.get(target, {}).get(actor, {}).get("relationship") == event.relationship_id:
					_remove_pair(relay, actor, target, "unavailable")
			if pending.size() >= 2048 and not pending.has(event.event_id):
				return
			pending[event.event_id] = {"sender": actor, "target": target, "deadline": now + 10000}
			var profile = value.get("profile", {})
			if not profile is Dictionary or (not profile.is_empty() and (profile.get("public_key") != own_key or not Identity.verify_profile(profile))):
				profile = {}
			_send(relay, target, {"op": "event", "event": event, "profile": profile})
		"receipt":
			var id = value.get("event_id")
			if not pending.has(id) or pending[id].target != actor:
				return
			var sender: int = pending[id].sender
			if not relay.key_mapping.has(sender) or relay.key_mapping[sender].public_key != value.get("recipient"):
				return
			pending.erase(id)
			_send(relay, sender, {"op": "receipt", "event_id": id, "actor": own_key})
		"authorize":
			var proof = value.get("proof")
			if not proof is Dictionary or not FriendEvent.valid_proof(proof) or not publications.has(actor) \
				or value.get("generation") != publications[actor].generation:
				return
			var request: Dictionary = proof.request
			if own_key not in [request.actor, request.recipient]:
				return
			var other: String = request.recipient if request.actor == own_key else request.actor
			var target = _id(relay, other)
			if target == -1:
				_presence(relay, actor, Identity.fingerprint(other), "offline")
				return # Never retain an absent user's key or fingerprint.
			if not grants.has(actor):
				grants[actor] = {}
			if grants[actor].size() >= 256 and not grants[actor].has(target):
				return
			grants[actor][target] = {"relationship": request.relationship_id, "expires": now + 15000}
			_update_pair(relay, actor, target)
		"unsubscribe":
			if not InstanceState.valid_fingerprint(value.get("target")):
				return
			for target in relay.key_mapping:
				if relay.key_mapping[target].fingerprint == value.target:
					_remove_pair(relay, actor, int(target), "unavailable")

func _presence(relay: Node, viewer: int, subject: String, status: String):
	if not publications.has(viewer):
		return
	sequence += 1
	_send(relay, viewer, {"op": "presence", "subject": subject, "status": status,
		"generation": publications[viewer].generation, "sequence": sequence})

func _update_pair(relay: Node, actor: int, target: int):
	if not relay.key_mapping.has(actor) or not relay.key_mapping.has(target):
		return
	var left: Dictionary = grants.get(actor, {}).get(target, {})
	var right: Dictionary = grants.get(target, {}).get(actor, {})
	var now = Time.get_ticks_msec()
	if left.is_empty() or right.is_empty() or left.relationship != right.relationship \
		or left.expires < now or right.expires < now or not publications.has(actor) or not publications.has(target):
		_presence(relay, actor, relay.key_mapping[target].fingerprint, "unavailable")
		return
	_presence(relay, actor, relay.key_mapping[target].fingerprint, publications[target].status)
	_presence(relay, target, relay.key_mapping[actor].fingerprint, publications[actor].status)

func _remove_pair(relay: Node, actor: int, target: int, status: String):
	if relay.key_mapping.has(target):
		_presence(relay, actor, relay.key_mapping[target].fingerprint, status)
	if relay.key_mapping.has(actor):
		_presence(relay, target, relay.key_mapping[actor].fingerprint, status)
	grants.get(actor, {}).erase(target)
	grants.get(target, {}).erase(actor)

func _clear_grants(relay: Node, actor: int, status: String):
	for target in relay.key_mapping.keys():
		if target != actor and (grants.get(actor, {}).has(target) or grants.get(target, {}).has(actor)):
			_remove_pair(relay, actor, int(target), status)
	grants.erase(actor)

func disconnect_peer(relay: Node, actor: int):
	_clear_grants(relay, actor, "offline")
	publications.erase(actor)
	rates.erase(actor)
	for id in pending.keys():
		if pending[id].sender == actor or pending[id].target == actor:
			pending.erase(id)

func tick(relay: Node):
	var now = Time.get_ticks_msec()
	for id in pending.keys():
		if pending[id].deadline < now:
			pending.erase(id)
	for actor in grants.keys():
		for target in grants.get(actor, {}).keys():
			if grants[actor][target].expires < now:
				_remove_pair(relay, actor, target, "unavailable")

extends RefCounted

signal changed
signal profile_changed(owner: String)
signal remote_profiles_changed
const Identity = preload("res://scripts/profile/profile_identity.gd")
const STATUSES = ["online", "do_not_disturb", "offline"]
var key: CryptoKey
var path := ""
var owner := ""
var state: Dictionary = {}
var last_error := ""
var write_blocked := false
var presence: Dictionary = {}
var connected := false
var supported := false
var generation := ""
var transport: Callable
var next_sync := 0
var delivery: Dictionary = {}
var self_profile: Dictionary = {}
var outbox_cursor := 0
var terminal_cursor := 0
var refreshing := false

func notifications_allowed() -> bool:
	return state.get("preferred_status", "online") != "do_not_disturb"

func configure(account_key: CryptoKey, config_path: String):
	disconnect_transport()
	key = account_key
	path = config_path
	owner = Identity.fingerprint(key.save_to_string(true)) if key != null else ""
	state = {"version": 1, "owner": key.save_to_string(true) if key != null else "", "revision": 0,
		"preferred_status": "online", "contacts": {}, "relationships": {}, "outbox": {}}
	last_error = ""
	write_blocked = false
	self_profile.clear()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 8 * 1024 * 1024:
			_fail_load("Friends file unreadable or too large; preserved for recovery")
			return
		var parser = JSON.new()
		var parse_error = parser.parse(file.get_as_text())
		var envelope = parser.data if parse_error == OK else null
		file.close()
		if not envelope is Dictionary or not envelope.get("data") is Dictionary or not envelope.get("signature") is String \
			or not _valid_store(envelope.data) or not _verify_store(envelope.data, envelope.signature):
			_fail_load("Friends file invalid, corrupt or belongs to another account; preserved for recovery")
			return
		state = envelope.data
	changed.emit()

func _fail_load(message: String):
	write_blocked = true
	last_error = message
	changed.emit()

func _store_bytes(data: Dictionary) -> PackedByteArray:
	return ("comunicare/friends-store/v1\n" + JSON.stringify(_canonical_numbers(data), "", true)).to_utf8_buffer()

func _canonical_numbers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == int(value):
		return int(value)
	if value is Dictionary:
		var result := {}
		for field in value:
			result[field] = _canonical_numbers(value[field])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonical_numbers(item))
		return result
	return value

func _verify_store(data: Dictionary, signature: String) -> bool:
	if signature.length() > 2048:
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, Identity.digest(_store_bytes(data)),
		Marshalls.base64_to_raw(signature), key)

func _valid_store(data: Dictionary) -> bool:
	for field in data:
		if field not in ["version", "owner", "revision", "preferred_status", "contacts", "relationships", "outbox"]:
			return false
	if data.get("version") != 1 or data.get("owner") != state.owner or not InstanceState.integer(data.get("revision")) \
		or data.get("preferred_status") not in STATUSES:
		return false
	for field in ["contacts", "relationships", "outbox"]:
		if not data.get(field) is Dictionary or data[field].size() > 2048:
			return false
	if data.contacts.size() > 128:
		return false
	for fingerprint in data.contacts:
		var contact = data.contacts[fingerprint]
		if not contact is Dictionary or not contact.get("public_key") is String \
			or Identity.fingerprint(contact.public_key) != fingerprint or fingerprint == owner \
			or not contact.get("nickname") is String or contact.nickname.length() > 128 or not contact.get("blocked") is bool:
			return false
		if not contact.get("profile", {}) is Dictionary:
			return false
		if not contact.get("profile", {}).is_empty() and (not Identity.verify_profile(contact.profile) or contact.profile.public_key != contact.public_key):
			return false
	for id in data.relationships:
		var record = data.relationships[id]
		if not record is Dictionary or not record.get("request") is Dictionary or not FriendEvent.valid(record.request) \
			or record.request.kind != "request" or record.request.relationship_id != id \
			or state.owner not in [record.request.actor, record.request.recipient] or not record.get("confirmed") is bool:
			return false
		if not record.has("accept") or not record.has("terminal"):
			return false
		for field in ["accept", "terminal"]:
			var event = record.get(field, {})
			if not event is Dictionary or (not event.is_empty() and (not FriendEvent.valid(event) or event.request != record.request)):
				return false
		if not record.accept.is_empty() and record.accept.kind != "accept":
			return false
		if not record.terminal.is_empty() and record.terminal.kind not in ["decline", "cancel", "revoke"]:
			return false
	for id in data.outbox:
		var event = data.outbox[id]
		if not event is Dictionary or not FriendEvent.valid(event) or event.actor != state.owner or event.event_id != id:
			return false
		if not data.relationships.has(event.relationship_id):
			return false
	return true

func _commit(next: Dictionary) -> bool:
	if write_blocked or key == null or key.is_public_only() or owner.is_empty():
		return _error("Account or Friends storage unavailable")
	next.revision = int(state.revision) + 1
	if JSON.stringify(next).length() > 7 * 1024 * 1024 or not _valid_store(next):
		return _error("Invalid friends data or storage limit reached")
	var signature = Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, Identity.digest(_store_bytes(next)), key))
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _error("Could not write friends file; no changes saved")
	file.store_string(JSON.stringify({"data": next, "signature": signature}, "", true))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return _error("Could not replace friends file; no changes saved")
	state = next
	last_error = ""
	changed.emit()
	remote_profiles_changed.emit()
	return true

func _error(message: String) -> bool:
	last_error = message
	changed.emit()
	return false

func add_contact(public_key: String, nickname: String = "", profile: Dictionary = {}) -> bool:
	var canonical = Identity.canonical_key(public_key.strip_edges() + "\n")
	if canonical.is_empty() or Identity.fingerprint(canonical) == owner or nickname.length() > 128:
		return _error("Enter another account's complete public key (not a private key)")
	var next = state.duplicate(true)
	var fingerprint = Identity.fingerprint(canonical)
	if not next.contacts.has(fingerprint):
		next.contacts[fingerprint] = {"public_key": canonical, "nickname": nickname, "blocked": false, "profile": {}}
	elif not nickname.is_empty():
		next.contacts[fingerprint].nickname = nickname
	if not profile.is_empty() and Identity.verify_profile(profile) and profile.public_key == canonical:
		next.contacts[fingerprint].profile = profile.duplicate(true)
	return _commit(next)

func contacts() -> Dictionary:
	return state.get("contacts", {}).duplicate(true)

func _other(request: Dictionary) -> String:
	return Identity.fingerprint(request.recipient if request.actor == state.owner else request.actor)

func relationship(fingerprint: String) -> Dictionary:
	var pending: Dictionary = {}
	for id in state.get("relationships", {}):
		var record: Dictionary = state.relationships[id]
		if _other(record.request) != fingerprint or not record.terminal.is_empty():
			continue
		if not record.accept.is_empty():
			if pending.get("status") == "friends" and not record.confirmed:
				continue
			if pending.get("status") == "friends" and pending.id < id:
				continue
			pending = {"id": id, "status": "friends" if record.confirmed else "accepting", "record": record.duplicate(true)}
			continue
		if pending.get("status") in ["friends", "accepting"]:
			continue
		if pending.get("status") != "incoming":
			pending = {"id": id, "status": "outgoing" if record.request.actor == state.owner else "incoming", "record": record.duplicate(true)}
	return pending

func is_friend(fingerprint: String) -> bool:
	return not state.get("contacts", {}).get(fingerprint, {}).get("blocked", false) and relationship(fingerprint).get("status") == "friends"

func send_request(fingerprint: String) -> bool:
	if not state.contacts.has(fingerprint) or state.contacts[fingerprint].blocked:
		return _error("Contact unavailable or blocked")
	if not relationship(fingerprint).is_empty():
		return _error("A friendship or request already exists; accept or cancel it first")
	return _local_event(FriendEvent.create(key, state.contacts[fingerprint].public_key, "request"))

func act(fingerprint: String, kind: String) -> bool:
	var relation = relationship(fingerprint)
	if relation.is_empty():
		return _error("No active relationship")
	if kind in ["accept", "decline"] and relation.status != "incoming":
		return _error("Only incoming requests can be accepted or declined")
	if kind == "cancel" and relation.status != "outgoing":
		return _error("Only your outgoing request can be cancelled")
	if kind not in ["accept", "decline", "cancel", "revoke"]:
		return false
	if kind == "revoke":
		return _terminate_pair(fingerprint)
	return _local_event(FriendEvent.create(key, state.contacts[fingerprint].public_key, kind, relation.record.request))

func _terminate_pair(fingerprint: String) -> bool:
	var next = state.duplicate(true)
	for record in next.relationships.values().duplicate():
		if _other(record.request) == fingerprint and record.terminal.is_empty():
			_apply(next, FriendEvent.create(key, state.contacts[fingerprint].public_key, "revoke", record.request), true)
	if not _commit(next):
		return false
	presence.erase(fingerprint)
	refresh()
	return true

func _apply(next: Dictionary, event: Dictionary, local: bool) -> bool:
	var request: Dictionary = event if event.kind == "request" else event.request
	var id: String = event.relationship_id
	if not next.relationships.has(id):
		next.relationships[id] = {"request": request.duplicate(true), "accept": {}, "terminal": {}, "confirmed": false}
	var record: Dictionary = next.relationships[id]
	if record.request != request:
		return false
	if event.kind == "accept":
		if not record.accept.is_empty():
			return record.accept == event
		record.accept = event.duplicate(true)
		record.confirmed = not local
	elif event.kind in ["decline", "cancel", "revoke"]:
		record.terminal = event.duplicate(true)
		record.confirmed = false
	if local:
		for queued_id in next.outbox.keys():
			if next.outbox[queued_id].relationship_id == id and event.kind in ["decline", "cancel", "revoke"]:
				next.outbox.erase(queued_id)
		next.outbox[event.event_id] = event.duplicate(true)
	return true

func _local_event(event: Dictionary) -> bool:
	var next = state.duplicate(true)
	if not _apply(next, event, true) or not _commit(next):
		return false
	presence.clear()
	refresh()
	return true

func block(fingerprint: String, blocked: bool = true) -> bool:
	if not state.contacts.has(fingerprint):
		return false
	var next = state.duplicate(true)
	if blocked:
		for record in next.relationships.values().duplicate():
			if _other(record.request) == fingerprint and record.terminal.is_empty():
				var event = FriendEvent.create(key, next.contacts[fingerprint].public_key, "revoke", record.request)
				_apply(next, event, true)
	next.contacts[fingerprint].blocked = blocked
	if not _commit(next):
		return false
	presence.erase(fingerprint)
	refresh()
	return true

func remove_contact(fingerprint: String) -> bool:
	if not relationship(fingerprint).is_empty():
		return _error("Cancel/remove friendship before deleting this saved contact")
	var next = state.duplicate(true)
	next.contacts.erase(fingerprint)
	return _commit(next)

func set_status(value: String) -> bool:
	if value not in STATUSES:
		return false
	var next = state.duplicate(true)
	next.preferred_status = value
	if not _commit(next):
		return false
	refresh()
	return true

func get_profile(fingerprint: String) -> Dictionary:
	if fingerprint == owner:
		return self_profile.duplicate(true)
	var contact: Dictionary = state.get("contacts", {}).get(fingerprint, {})
	var profile: Dictionary = contact.get("profile", {}).duplicate(true)
	if profile.is_empty() and not contact.is_empty():
		profile = Identity.defaults()
		profile.public_key = contact.public_key
		profile["profile.username"] = contact.nickname if not contact.nickname.is_empty() else fingerprint.left(12)
		profile["profile.avatar_url"] = ""
	return profile

func can_edit(_fingerprint: String) -> bool:
	return false # Cached social profiles never grant editing rights.

func label(fingerprint: String) -> String:
	var contact: Dictionary = state.contacts.get(fingerprint, {})
	if not contact.get("nickname", "").is_empty():
		return contact.nickname
	return str(get_profile(fingerprint).get("profile.username", fingerprint.left(12)))

func relationship_label(fingerprint: String) -> String:
	var terminal := "Saved locally"
	for record in state.relationships.values():
		if _other(record.request) == fingerprint and not record.terminal.is_empty():
			terminal = {"decline": "Declined", "cancel": "Cancelled", "revoke": "Removed"}.get(record.terminal.kind, terminal)
	return terminal

func status(fingerprint: String) -> String:
	if not connected or not supported or not is_friend(fingerprint):
		return "Status unavailable"
	var value: Dictionary = presence.get(fingerprint, {})
	if value.is_empty() or Time.get_ticks_msec() - value.received > 15000:
		return "Status unavailable"
	return {"online": "Online", "offline": "Offline", "do_not_disturb": "Do Not Disturb", "unavailable": "Status unavailable"}.get(value.status, "Status unavailable")

func attach(send: Callable, capability: bool):
	disconnect_transport()
	transport = send
	connected = true
	supported = capability
	generation = Crypto.new().generate_random_bytes(32).hex_encode()
	refresh()

func disconnect_transport():
	connected = false
	supported = false
	transport = Callable()
	presence.clear()
	delivery.clear()
	generation = ""
	changed.emit()

func _send(value: Dictionary):
	if connected and supported and transport.is_valid():
		transport.call(value)

func refresh():
	if refreshing:
		next_sync = 0
		return
	refreshing = true
	next_sync = Time.get_ticks_msec() + 5000
	if not connected or not supported or write_blocked:
		refreshing = false
		changed.emit()
		return
	_send({"op": "publish", "status": state.preferred_status, "generation": generation})
	var queued: Array = state.outbox.values()
	for event in _batch(queued, outbox_cursor):
		_send({"op": "event", "event": event, "profile": self_profile})
	outbox_cursor += 32
	for fingerprint in state.contacts:
		var relation = relationship(fingerprint)
		if is_friend(fingerprint):
			_send({"op": "authorize", "generation": generation,
				"proof": {"request": relation.record.request, "accept": relation.record.accept}})
		else:
			_send({"op": "unsubscribe", "target": fingerprint})
	# Re-deliver terminal records only to their intended counterpart so an old
	# restored client cannot reauthorize a removed relationship on reconnect.
	var terminal_events: Array = []
	for record in state.relationships.values():
		if not record.terminal.is_empty() and record.terminal.actor == state.owner:
			terminal_events.append(record.terminal)
	for event in _batch(terminal_events, terminal_cursor):
		_send({"op": "event", "event": event, "profile": {}})
	terminal_cursor += 32
	refreshing = false
	changed.emit()

func _batch(values: Array, cursor: int) -> Array:
	var result: Array = []
	if not values.is_empty():
		for i in mini(32, values.size()):
			result.append(values[(cursor + i) % values.size()])
	return result

func tick():
	if connected and Time.get_ticks_msec() >= next_sync:
		refresh()
	var expired := false
	for fingerprint in presence.keys():
		if Time.get_ticks_msec() - presence[fingerprint].received > 15000:
			presence.erase(fingerprint)
			expired = true
	if expired:
		changed.emit()

func receive(value: Dictionary):
	match value.get("op"):
		"event":
			_receive_event(value)
		"receipt":
			var id = value.get("event_id")
			if not state.outbox.has(id) or state.outbox[id].recipient != value.get("actor"):
				return
			var event: Dictionary = state.outbox[id]
			var next = state.duplicate(true)
			next.outbox.erase(id)
			if event.kind == "accept" and next.relationships.has(event.relationship_id):
				next.relationships[event.relationship_id].confirmed = true
			if _commit(next) and event.kind == "accept":
				refresh()
		"presence":
			var fingerprint = value.get("subject")
			if value.get("generation") != generation or not is_friend(str(fingerprint)) \
				or value.get("status") not in STATUSES + ["unavailable"] or not InstanceState.integer(value.get("sequence")):
				return
			if value.sequence <= presence.get(fingerprint, {}).get("sequence", -1):
				return
			presence[fingerprint] = {"status": value.status, "sequence": value.sequence, "received": Time.get_ticks_msec()}
			changed.emit()
		"delivery":
			delivery[value.get("event_id", "")] = value.get("status", "unavailable")

func _receive_event(value: Dictionary):
	var event = value.get("event")
	if not event is Dictionary or not FriendEvent.valid(event) or event.recipient != state.owner:
		return
	var fingerprint = Identity.fingerprint(event.actor)
	if state.contacts.get(fingerprint, {}).get("blocked", false):
		return
	var known: Dictionary = state.relationships.get(event.relationship_id, {})
	if not known.is_empty():
		for field in ["request", "accept", "terminal"]:
			if known[field] == event:
				_send({"op": "receipt", "event_id": event.event_id, "recipient": event.actor})
				return # Already durably stored; no writes or refresh loop.
	var next = state.duplicate(true)
	for record in next.relationships.values():
		for field in ["request", "accept", "terminal"]:
			var existing: Dictionary = record[field]
			if not existing.is_empty() and existing.event_id == event.event_id and existing != event:
				return
	if event.kind == "request" and is_friend(fingerprint) and not next.relationships.has(event.relationship_id):
		return
	if not next.contacts.has(fingerprint):
		next.contacts[fingerprint] = {"public_key": event.actor, "nickname": "", "blocked": false, "profile": {}}
	var profile = value.get("profile", {})
	if profile is Dictionary and not profile.is_empty() and profile.get("public_key") == event.actor and Identity.verify_profile(profile):
		next.contacts[fingerprint].profile = profile.duplicate(true)
	var old_record: Dictionary = next.relationships.get(event.relationship_id, {})
	if not old_record.is_empty():
		var existing = old_record.get("accept", {}) if event.kind == "accept" else old_record.get("terminal", {})
		if not existing.is_empty() and existing.event_id == event.event_id and existing != event:
			return
	if not _apply(next, event, false) or not _commit(next):
		return
	_send({"op": "receipt", "event_id": event.event_id, "recipient": event.actor})
	presence.erase(fingerprint)
	refresh()

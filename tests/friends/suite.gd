extends SceneTree

const Service = preload("res://scripts/profile/friend_service.gd")
const Identity = preload("res://scripts/profile/profile_identity.gd")
var passed := 0
var failed := 0
var keys: Array = []
var services: Array = []
var clients: Array = []
var relay: Node

func _initialize():
	call_deferred("run")

func check(ok: bool, text: String):
	if ok:
		passed += 1
		print("PASS: ", text)
	else:
		failed += 1
		print("FAIL: ", text)

func fp(i: int) -> String:
	return Identity.fingerprint(keys[i].save_to_string(true))

func test_storage():
	var a = services[0]
	check(a.add_contact(keys[1].save_to_string(true), "Bob"), "save public-key contact locally")
	check(a.add_contact(keys[1].save_to_string(true)) and a.contacts().size() == 1, "duplicate key does not duplicate contact")
	check(a.relationship(fp(1)).is_empty(), "saving contact does not create request or friendship")
	check(not a.add_contact(keys[0].save_to_string(true)) and not a.add_contact(keys[1].save_to_string(false)), "self and private-key input rejected")
	var restored = Service.new()
	restored.configure(keys[0], "res://friends-0.cfg")
	check(restored.contacts().size() == 1 and restored.label(fp(1)) == "Bob", "contacts and local nickname survive signed-store reload")
	var wrong = Service.new()
	wrong.configure(keys[2], "res://friends-0.cfg")
	check(wrong.write_blocked and wrong.contacts().is_empty(), "wrong account cannot adopt contacts file")
	var text = FileAccess.get_file_as_string("res://friends-0.cfg")
	check(not "PRIVATE KEY" in text, "persistent friend store never contains private key")
	var corrupt = FileAccess.open("res://corrupt.cfg", FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	wrong.configure(keys[2], "res://corrupt.cfg")
	check(wrong.write_blocked and not wrong.add_contact(keys[1].save_to_string(true)) \
		and FileAccess.get_file_as_string("res://corrupt.cfg") == "broken", "corrupt store preserved instead of overwritten")

func test_consent():
	var a = services[0]
	var b = services[1]
	check(a.send_request(fp(1)) and not a.is_friend(fp(1)), "sending request alone never grants friendship")
	var request: Dictionary = a.state.outbox.values()[0]
	b.receive({"op": "event", "event": request})
	check(b.relationship(fp(0)).status == "incoming" and not b.is_friend(fp(0)), "verified request requires recipient acceptance")
	var forged = FriendEvent.create(keys[2], keys[0].save_to_string(true), "accept", request)
	check(not FriendEvent.valid(forged), "third party cannot accept someone else's request")
	check(b.act(fp(0), "accept") and not b.is_friend(fp(0)), "local acceptance waits for durable sender receipt")
	var acceptance: Dictionary = b.state.outbox.values()[0]
	a.receive({"op": "event", "event": acceptance})
	b.receive({"op": "receipt", "event_id": acceptance.event_id, "actor": keys[0].save_to_string(true)})
	check(a.is_friend(fp(1)) and b.is_friend(fp(0)), "matching signed request and acceptance establish mutual friendship")
	check(a.act(fp(1), "revoke") and not a.is_friend(fp(1)), "remove friend revokes locally immediately")
	a.receive({"op": "event", "event": acceptance})
	check(not a.is_friend(fp(1)), "late acceptance cannot resurrect revoked relationship")
	var revoke: Dictionary = a.state.outbox.values().filter(func(value): return value.kind == "revoke")[0]
	b.receive({"op": "event", "event": revoke})
	check(not b.is_friend(fp(0)), "signed revocation removes remote friendship")
	check(a.block(fp(1)) and a.block(fp(1), false) and not a.is_friend(fp(1)), "unblock does not restore old friendship")
	# Fresh request after terminal state; discard delivered test outboxes via receipts.
	for service in services:
		for event in service.state.outbox.values().duplicate():
			service.receive({"op": "receipt", "event_id": event.event_id, "actor": event.recipient})

func test_additional_contracts():
	var a = Service.new()
	var b = Service.new()
	a.configure(keys[0], "res://cross-a.cfg")
	b.configure(keys[1], "res://cross-b.cfg")
	a.add_contact(keys[1].save_to_string(true))
	b.add_contact(keys[0].save_to_string(true))
	a.send_request(fp(1))
	b.send_request(fp(0))
	var left: Dictionary = a.state.outbox.values()[0]
	var right: Dictionary = b.state.outbox.values()[0]
	a.receive({"op": "event", "event": right})
	b.receive({"op": "event", "event": left})
	check(not a.is_friend(fp(1)) and not b.is_friend(fp(0)) and a.relationship(fp(1)).status == "incoming",
		"crossed signed requests still require explicit acceptance")
	a.act(fp(1), "accept")
	var acceptance: Dictionary = a.state.outbox.values().filter(func(value): return value.kind == "accept")[0]
	b.receive({"op": "event", "event": acceptance})
	a.receive({"op": "receipt", "event_id": acceptance.event_id, "actor": keys[1].save_to_string(true)})
	check(a.is_friend(fp(1)) and b.is_friend(fp(0)), "explicit acceptance resolves crossed requests")
	a.act(fp(1), "revoke")
	check(not a.is_friend(fp(1)) and a.relationship(fp(1)).is_empty(), "removal closes every active relationship for the account pair")
	var changed_event = left.duplicate(true)
	changed_event.recipient = keys[2].save_to_string(true)
	check(not FriendEvent.valid(changed_event), "altered signed recipient is rejected")
	var extra = left.duplicate(true)
	extra.extra = "unsigned data"
	check(not FriendEvent.valid(extra), "unsigned extra event fields are rejected")
	var original = FileAccess.get_file_as_string("res://cross-a.cfg")
	var parsed = JSON.parse_string(original)
	parsed.data.preferred_status = "offline"
	var file = FileAccess.open("res://tampered.cfg", FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()
	var tampered = Service.new()
	tampered.configure(keys[0], "res://tampered.cfg")
	check(tampered.write_blocked, "signed store detects edited status/contact data")
	var failure = Service.new()
	failure.configure(keys[0], "res://missing-directory/friends.cfg")
	check(not failure.add_contact(keys[1].save_to_string(true)) and failure.contacts().is_empty(),
		"write failure does not mutate usable local contacts")
	b.block(fp(0))
	var fresh = FriendEvent.create(keys[0], keys[1].save_to_string(true), "request")
	b.receive({"op": "event", "event": fresh})
	check(not b.state.relationships.has(fresh.relationship_id), "blocked accounts cannot fill incoming inbox")
	var c = Service.new()
	c.configure(keys[2], "res://decline.cfg")
	var invitation = FriendEvent.create(keys[0], keys[2].save_to_string(true), "request")
	c.receive({"op": "event", "event": invitation})
	check(c.act(fp(0), "decline") and not c.is_friend(fp(0)) and c.relationship(fp(0)).is_empty(),
		"explicit decline closes incoming request without friendship")
	check(c.send_request(fp(0)) and c.act(fp(0), "cancel") and c.relationship(fp(0)).is_empty(),
		"sender can cancel its own queued request")
	c.set_status("do_not_disturb")
	check(not c.notifications_allowed() and c.state.outbox.size() > 0, "DND disables social interruptions without deleting queued actions")


func run():
	for i in 3:
		keys.append(Crypto.new().generate_rsa(2048))
		var service = Service.new()
		service.configure(keys[i], "res://friends-%d.cfg" % i)
		services.append(service)
	test_storage()
	test_consent()
	test_additional_contracts()
	print("Friends core: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

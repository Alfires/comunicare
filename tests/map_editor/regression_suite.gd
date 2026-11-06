extends SceneTree
var failed := 0
var passed := 0
const Commands = preload("res://scripts/editor/edit_commands.gd")
const Authority = preload("res://scripts/editor/edit_authority.gd")
const Session = preload("res://scripts/editor/edit_session.gd")
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	print("PASS: " if value else "FAIL: ", label)
	if value: passed += 1
	else: failed += 1
func source() -> Dictionary:
	return {"schema": 1, "world_id": "test", "title": "Test", "revision": 0, "entities": [{"id": "spawn", "name": "Spawn", "type": "spawn", "position": [0, 1, 0]}], "assets": [], "behaviors": [], "capabilities": []}
func operation(revision: Variant = 0) -> Dictionary:
	return {"id": "move", "generation": "session", "revision": revision, "op": "set_transform", "entity": "spawn", "position": [1, 2, 3]}
func run():
	var commands = Commands.new()
	var op = operation()
	var result = commands.apply_operation(source(), op)
	op.position[0] = 999
	check(result.ok and result.document.entities[0].position == [1, 2, 3], "applied transform owns its position instead of aliasing caller input")
	for revision in [-1, 0.5, true, "0", 2147483647]:
		var document = source()
		document.revision = revision
		check(not commands.apply_operation(document, operation(revision)).ok, "invalid or exhausted source revision rejected: " + str(revision))
	var unsupported = operation()
	unsupported.rotation = [0, 1, 0]
	check(not commands.apply_operation(source(), unsupported).ok, "unsupported transform fields cannot be silently discarded")
	var authority = Authority.new()
	authority.configure(source(), "", "session")
	check(not authority.admit("", "intruder", "editor").ok, "empty owner cannot authorize members")
	check(not authority.snapshot("").ok, "empty owner cannot read a configured project")
	authority.configure(source(), "owner", "")
	var empty_generation = operation()
	empty_generation.generation = ""
	check(not authority.submit("owner", empty_generation).ok, "empty generation cannot authorize edits")
	authority.configure(source(), "owner", "session")
	var committed = authority.submit("owner", operation())
	committed.document.entities[0].position[0] = 999
	check(authority.snapshot("owner").document.entities[0].position == [1, 2, 3], "authority result cannot be mutated to bypass revision and permission checks")
	var leases = preload("res://scripts/editor/edit_leases.gd").new()
	check(not leases.acquire("session", "spawn", "member", 9223372036854775800, 100).ok, "overflowing lease expiry is rejected")
	var session = Session.new()
	root.add_child(session)
	check(session.host(source(), Crypto.new().generate_rsa(2048)), "lifecycle regression host starts")
	var close_notifications = [0]
	session.changed.connect(func(): close_notifications[0] += 1)
	session.challenge = {"nonce": "old-nonce"}
	session.last_error = "old error"
	session.close()
	check(close_notifications[0] == 1, "closing live session notifies editor controls of disconnected state")
	check(session.document.is_empty() and session.authority.document.is_empty(), "closed session releases project and authority snapshots")
	check(session.generation.is_empty() and session.owner_fingerprint.is_empty() and session.authority.owner.is_empty() and session.authority.generation.is_empty(), "closed session clears identity and generation")
	check(session.challenge.is_empty() and session.last_error.is_empty(), "closed session clears handshake and error state")
	check(not session.join("127.0.0.1", 12345, "z".repeat(64), Crypto.new().generate_rsa(2048)), "join rejects nonhex owner fingerprints before opening transport")
	session.close()
	session.free()
	print("Editor regressions: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

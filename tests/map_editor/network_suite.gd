extends SceneTree
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	print("PASS: " if ok else "FAIL: ", title)
	if not ok: failed += 1
func wait_for(predicate: Callable) -> bool:
	var until = Time.get_ticks_msec() + 5000
	while not predicate.call() and Time.get_ticks_msec() < until: await create_timer(0.01).timeout
	return predicate.call()
func run():
	var host = load("res://scripts/editor/edit_session.gd").new()
	var client = load("res://scripts/editor/edit_session.gd").new()
	root.add_child(host)
	root.add_child(client)
	var source = {"schema": 1, "world_id": "test", "title": "Test", "revision": 0, "entities": [{"id": "spawn", "name": "Spawn", "type": "spawn", "position": [0, 1, 0]}], "assets": [], "behaviors": [], "capabilities": []}
	check(host.host(source, Crypto.new().generate_rsa(2048)), "real ENet edit host starts")
	var client_key = Crypto.new().generate_rsa(2048)
	check(client.join("127.0.0.1", host.connection.get_local_port(), host.owner_fingerprint, client_key), "client starts pinned-owner authenticated join")
	check(await wait_for(func(): return host.pending.values().any(func(v): return v.get("verified", false))), "challenge signatures authenticate requesting account")
	check(not client.authenticated and client.document.is_empty(), "unapproved client receives no project")
	var fingerprint = load("res://scripts/profile/profile_identity.gd").fingerprint(client_key.save_to_string(true))
	check(host.approve(fingerprint, "viewer"), "owner grants viewer access")
	check(await wait_for(func(): return client.authenticated), "approved viewer receives validated snapshot")
	check(not client.move_entity("spawn", [3, 1, 0]), "viewer cannot send movement edit")
	host.revoke(fingerprint)
	check(await wait_for(func(): return not client.authenticated), "revocation disconnects client")
	check(client.join("127.0.0.1", host.connection.get_local_port(), host.owner_fingerprint, client_key), "revoked account can request fresh approval")
	check(await wait_for(func(): return host.pending.values().any(func(v): return v.get("verified", false))), "rejoin authenticates fresh challenge")
	check(host.approve(fingerprint, "editor"), "owner grants editor role explicitly")
	await wait_for(func(): return client.authenticated)
	check(client.move_entity("spawn", [3, 1, 0]), "editor submits movement")
	check(await wait_for(func(): return host.document.get("revision") == 1 and client.document.get("revision") == 1), "host and client converge on canonical revision")
	check(host.document.entities[0].position == [3, 1, 0], "authenticated edit changes exact entity")
	client.close()
	await wait_for(func(): return host.members.is_empty())
	check(host.members.is_empty() and not host.authority.roles.has(fingerprint), "disconnect clears member permissions")
	host.free()
	client.free()
	print("Editor network failures: ", failed)
	quit(1 if failed else 0)

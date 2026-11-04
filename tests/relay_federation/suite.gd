extends SceneTree
## Proposed pure service contracts. No test double implements federation behavior.
const A = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const B = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const C = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
var passed := 0
var failed := 0
var blocked: Array[String] = []

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func component(name: String, methods: Array):
	var path = "res://scripts/multiplayer/federation/" + name + ".gd"
	if not ResourceLoader.exists(path):
		check(false, "missing production component: " + name)
		blocked.append(name)
		return null
	var script = load(path)
	if script == null or not script.can_instantiate():
		check(false, "instantiable production component: " + name)
		blocked.append(name)
		return null
	var service = script.new()
	for method in methods:
		if not service.has_method(method):
			check(false, name + " implements " + method)
			blocked.append(name)
			dispose(service)
			return null
	return service

func dispose(service):
	if service is Node: service.free()

func ok(value: Variant) -> bool:
	return value is Dictionary and value.get("ok", false) == true

func denied(value: Variant) -> bool:
	return value is Dictionary and value.get("ok", true) == false and value.get("error", "") is String and not value.error.is_empty()

func entry(id: String, identity: String, port: int) -> Dictionary:
	return {"entry_id": id, "label": id, "host": "127.0.0.1", "port": port, "relay_id": identity}

func entries() -> Array:
	return [entry("first", A, 17001), entry("second", B, 17002), entry("third", C, 17003)]

func run():
	test_preferences()
	test_failover()
	test_route_policy()
	test_directory()
	test_lan()
	test_origin_state()
	print("\nFederation acceptance: %s passed, %s failed; %s BLOCKED groups: %s" % [passed, failed, blocked.size(), ", ".join(blocked)])
	print("Blocked behaviors are not executed/passed. Pure contracts do not verify TLS, actual LAN, relay transport or headset rendering.")
	quit(1 if failed else 0)

func test_preferences():
	var store = component("relay_preferences", ["configure", "load_preferences", "snapshot", "add_entry", "move_entry", "remove_entry", "set_blocked", "save_preferences", "migrate_legacy"])
	if store == null: return
	store.configure("user://relay-preferences.json")
	check(ok(store.load_preferences()), "missing preferences initialize without account or relay writes")
	for value in entries(): check(ok(store.add_entry(value)), "add saved relay " + value.entry_id)
	check(store.snapshot().get("entries", []) == entries(), "saved order defines main and fallback priority")
	check(denied(store.add_entry(entry("duplicate", A, 17001))), "duplicate identity/endpoint rejected")
	check(denied(store.add_entry(entry("bad", C, 0))), "invalid UDP port rejected")
	check(ok(store.move_entry("third", 0)) and store.snapshot().entries[0].relay_id == C, "make main moves relay to top")
	check(ok(store.set_blocked(B, true)), "blocking records identity independently of order")
	check(ok(store.remove_entry("second")) and B in store.snapshot().get("blocked_ids", []), "removing relay never removes its block")
	check(ok(store.save_preferences()), "client-local relay preferences save atomically")
	var restored = load("res://scripts/multiplayer/federation/relay_preferences.gd").new()
	restored.configure("user://relay-preferences.json")
	check(ok(restored.load_preferences()) and restored.snapshot() == store.snapshot(), "order and blocks survive local reload")
	check(ok(restored.set_blocked(B, false)) and restored.snapshot().entries.size() == 2, "unblock does not reinsert removed relay")
	var corrupt = FileAccess.open("user://corrupt-relays.json", FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	restored.configure("user://corrupt-relays.json")
	check(denied(restored.load_preferences()) and denied(restored.save_preferences()), "corrupt preference store blocks overwrite")
	check(FileAccess.get_file_as_string("user://corrupt-relays.json") == "{broken", "corrupt original preserved for recovery")
	restored.configure("user://migration.json")
	check(ok(restored.migrate_legacy("127.0.0.1", 7374)), "legacy scalar endpoint migrates to first entry")
	var before: Dictionary = restored.snapshot().duplicate(true)
	check(ok(restored.migrate_legacy("elsewhere.invalid", 1234)) and restored.snapshot() == before, "repeated migration never overwrites an existing ordered list")
	dispose(restored)
	dispose(store)

func test_failover():
	var manager = component("relay_connection_manager", ["configure", "begin_selection", "complete_attempt", "snapshot", "set_blocked", "retry", "tick", "open_directory"])
	if manager == null: return
	manager.configure(entries(), [], {"max_connections": 4, "attempt_timeout_ms": 1000})
	var first: Dictionary = manager.begin_selection(0)
	check(first.get("relay_id") == A, "selection always starts with top preferred relay")
	check(manager.begin_selection(1).get("attempt_id") == first.get("attempt_id"), "concurrent selection calls coalesce one in-flight attempt")
	var second: Dictionary = manager.complete_attempt(first.attempt_id, {"status": "capacity_full", "relay_id": A}, 10)
	check(second.get("relay_id") == B, "full main relay advances to next saved entry")
	var third: Dictionary = manager.complete_attempt(second.attempt_id, {"status": "unavailable"}, 20)
	check(third.get("relay_id") == C, "unavailable fallback advances to third entry")
	check(ok(manager.complete_attempt(third.attempt_id, {"status": "authenticated", "relay_id": C}, 30)), "third saved relay can become authenticated ingress")
	check(manager.snapshot().get("current_relay_id") == C and manager.snapshot().get("entries") == entries(), "successful fallback does not reorder saved preference list")
	check(ok(manager.open_directory(A)) and ok(manager.open_directory(B)), "multiple directory links coexist with active fallback ingress")
	check(manager.snapshot().get("current_relay_id") == C and manager.snapshot().get("directory_relays", []).size() == 2, "additional relay use does not replace gameplay ingress")
	manager.tick(5000)
	check(manager.snapshot().get("current_relay_id") == C, "healthy fallback never forcibly fails back to recovered main")
	check(denied(manager.complete_attempt(first.attempt_id, {"status": "authenticated", "relay_id": A}, 5001)), "stale success cannot replace chosen ingress")
	manager.set_blocked(C, true)
	check(manager.snapshot().get("current_relay_id", "") != C, "blocking active relay immediately invalidates ingress")
	var retry: Dictionary = manager.retry(6000)
	manager.set_blocked(A, true)
	check(denied(manager.complete_attempt(retry.get("attempt_id", ""), {"status": "authenticated", "relay_id": A}, 6001)), "block during authentication invalidates pending success")
	manager.configure(entries(), [A, B, C], {"max_connections": 4, "attempt_timeout_ms": 1000})
	check(denied(manager.begin_selection(0)), "all saved relays blocked leaves explicit offline result")
	check(denied(manager.open_directory(A)), "blocked relay cannot be opened as secondary directory link")
	manager.configure(entries(), [], {"max_connections": 4, "attempt_timeout_ms": 1000})
	first = manager.begin_selection(0)
	check(denied(manager.complete_attempt(first.attempt_id, {"status": "redirect", "host": "attacker.invalid"}, 1)), "failed relay cannot redirect credentials outside saved candidates")
	manager.configure(entries(), [], {"max_connections": 4, "attempt_timeout_ms": 1000})
	first = manager.begin_selection(0)
	manager.tick(1001)
	check(manager.snapshot().get("pending", {}).get("relay_id") == B, "bounded timeout advances without per-frame reconnect storm")
	manager.configure(entries(), [], {"max_connections": 1, "attempt_timeout_ms": 1000})
	first = manager.begin_selection(0)
	manager.complete_attempt(first.attempt_id, {"status": "authenticated", "relay_id": A}, 1)
	check(denied(manager.open_directory(B)), "simultaneous link cap prevents unbounded secondary connections")
	dispose(manager)

func test_route_policy():
	var policy = component("relay_route_policy", ["configure", "authorize", "set_user_blocked", "set_operator_blocked"])
	if policy == null: return
	var route = {"origin": C, "ingress": A, "path": [A, B, C], "verified": true, "policy_epoch": 1}
	policy.configure([], [], 1, 4)
	check(ok(policy.authorize(route)), "allowed authenticated multi-relay route accepted")
	policy.set_user_blocked(C, true)
	check(denied(policy.authorize(route)), "user origin block cannot be bypassed through middle relay")
	policy.configure([], [C], 1, 4)
	check(denied(policy.authorize(route)), "operator origin block also denies indirect route")
	policy.configure([B], [], 1, 4)
	check(denied(policy.authorize(route)), "blocked intermediate hop is not an allowed route")
	policy.configure([A], [], 1, 4)
	check(denied(policy.authorize(route)), "blocked actor ingress cannot hide behind allowed origin")
	policy.configure([], [], 1, 4)
	for changed in [{"path": [A, B, A, C]}, {"verified": false}, {"policy_epoch": 0}, {"path": [A, B]}, {"origin": "forged"}]:
		var invalid = route.duplicate(true)
		invalid.merge(changed, true)
		check(denied(policy.authorize(invalid)), "reject loop/unverified/stale/mismatched route: " + str(changed))
	dispose(policy)

func summary(origin: String = A, boot: String = "boot-1", mode: int = 0) -> Dictionary:
	return {"origin_relay_id": origin, "origin_boot_id": boot, "instance_id": "same-local-code", "world_url": "https://example.invalid/world.cworld", "world_revision": C, "mode": mode, "name": "Public room", "description": "", "player_count": 2}

func test_directory():
	var directory = component("federation_directory", ["configure", "ingest", "snapshot", "set_blocked", "withdraw_origin", "expire"])
	if directory == null: return
	directory.configure({"max_instances": 16, "ttl_ms": 15000}, [])
	check(ok(directory.ingest(A, "boot-1", 1, [summary()], [A], 0)), "authenticated public origin directory accepted")
	check(ok(directory.ingest(B, "boot-1", 1, [summary(B)], [B], 0)) and directory.snapshot().size() == 2, "same local code and world URL on two relays remain distinct instances")
	check(ok(directory.ingest(A, "boot-1", 2, [summary()], [B, A], 1)) and directory.snapshot().size() == 2, "direct and routed sightings deduplicate same global instance")
	for mode in [1, 2, 3, 4]:
		check(denied(directory.ingest(C, "boot-1", 1, [summary(C, "boot-1", mode)], [C], 2)), "nonpublic access mode never enters public federation: " + str(mode))
	var leaked = summary(C)
	leaked.admins = ["private-account"]
	check(denied(directory.ingest(C, "boot-1", 1, [leaked], [C], 3)), "directory rejects roster/admin/private fields")
	check(denied(directory.ingest(A, "boot-1", 1, [summary()], [A], 4)), "older origin sequence cannot replace fresher summary")
	directory.set_blocked(A, true)
	check(directory.snapshot().size() == 1 and denied(directory.ingest(A, "boot-1", 3, [summary()], [B, A], 5)), "blocking origin purges sightings and rejects indirect reappearance")
	directory.withdraw_origin(B, "boot-1")
	check(directory.snapshot().is_empty(), "withdrawal removes disconnected origin summaries")
	directory.configure({"max_instances": 16, "ttl_ms": 15000}, [])
	directory.ingest(A, "boot-1", 1, [summary()], [A], 0)
	directory.expire(15001)
	check(directory.snapshot().is_empty(), "unrefreshed federation summaries expire without explicit withdrawal")
	dispose(directory)

func test_lan():
	var lan = component("lan_relay_discovery", ["configure", "observe", "candidates", "verified_directory", "instances", "expire"])
	if lan == null: return
	lan.configure({"enabled": true, "max_candidates": 2, "ttl_ms": 10000}, [B])
	var advertisement = {"version": 1, "relay_id": A, "boot_id": "boot-1", "label": "LAN relay", "host": "192.168.10.2", "port": 7374}
	check(ok(lan.observe(JSON.stringify(advertisement).to_utf8_buffer(), "192.168.10.2", 0)), "valid LAN advertisement becomes unverified candidate")
	check(lan.candidates().size() == 1 and lan.instances().is_empty(), "advertisement alone cannot become joinable instance")
	check(ok(lan.verified_directory(A, "boot-1", [summary()], 1)) and lan.instances().size() == 1, "identity-verified LAN public instance enters world-list model")
	check(ok(lan.observe(JSON.stringify(advertisement).to_utf8_buffer(), "192.168.10.2", 2)) and lan.candidates().size() == 1, "duplicate LAN advertisements cannot inflate candidate count")
	var blocked_ad = advertisement.duplicate(true)
	blocked_ad.relay_id = B
	check(denied(lan.observe(JSON.stringify(blocked_ad).to_utf8_buffer(), "192.168.10.2", 3)), "blocked relay ignored before LAN directory request")
	var remote_ad = advertisement.duplicate(true)
	remote_ad.host = "8.8.8.8"
	check(denied(lan.observe(JSON.stringify(remote_ad).to_utf8_buffer(), "192.168.10.2", 3)), "LAN advertisement cannot trigger public Internet probes")
	check(denied(lan.observe("broken JSON".to_utf8_buffer(), "192.168.10.2", 3)), "malformed LAN datagram rejected quietly")
	check(denied(lan.observe("x".repeat(1025).to_utf8_buffer(), "192.168.10.2", 3)), "LAN datagram size capped before parse")
	check(denied(lan.verified_directory(A, "different-boot", [summary()], 4)), "wrong boot cannot verify stale advertisement")
	lan.expire(10003)
	check(lan.candidates().is_empty() and lan.instances().is_empty(), "LAN expiry removes candidate and dependent instances")
	lan.configure({"enabled": false, "max_candidates": 2, "ttl_ms": 10000}, [])
	check(denied(lan.observe(JSON.stringify(advertisement).to_utf8_buffer(), "192.168.10.2", 0)), "user LAN opt-out stops candidate ingestion")
	dispose(lan)

func test_origin_state():
	var state = component("federated_instance_state", ["configure", "admit", "apply_item", "snapshot", "disconnect_actor", "lose_origin"])
	if state == null: return
	var instance = {"origin_relay_id": C, "origin_boot_id": "boot-1", "instance_id": "room", "world_revision": C}
	state.configure(instance, ["cup"])
	var alice = {"account": A, "ingress_relay_id": A, "peer_id": 7, "generation": "alice-1"}
	var bob = {"account": B, "ingress_relay_id": B, "peer_id": 7, "generation": "bob-1"}
	check(denied(state.admit(alice, {"verified": false})), "ingress cannot assert unverified account membership")
	check(ok(state.admit(alice, {"verified": true, "instance": instance, "fresh": true})), "origin admits fresh destination-bound account proof")
	check(ok(state.admit(bob, {"verified": true, "instance": instance, "fresh": true})), "same byte peer ID through different ingress does not collide")
	var event = {"kind": "grab", "instance": instance, "entity": "cup", "grip": "virtual", "epoch": 0, "sequence": 1}
	check(ok(state.apply_item(alice, event)), "one origin grants desktop item lease across relays")
	var epoch = int(state.snapshot().get("items", {}).get("cup", {}).get("epoch", -1))
	event.epoch = epoch
	event.grip = "left"
	check(denied(state.apply_item(bob, event)), "second ingress cannot independently grant same item to VR actor")
	var stale = alice.duplicate(true)
	stale.generation = "old-connection"
	check(denied(state.apply_item(stale, event)), "old actor generation cannot use current origin lease")
	var different = event.duplicate(true)
	different.instance.world_revision = A
	check(denied(state.apply_item(alice, different)), "world hash mismatch rejects cross-relay item operation")
	state.disconnect_actor(alice)
	check(not JSON.stringify(state.snapshot()).contains("alice-1") and not JSON.stringify(state.snapshot()).contains(A), "disconnect removes actor identity and indirect holder references")
	state.lose_origin()
	check(state.snapshot().get("suspended", false) and denied(state.apply_item(bob, event)), "origin loss suspends operations instead of electing competing authority")
	dispose(state)

extends SceneTree

const Store = preload("res://scripts/worlds/world_local_store.gd")
const Runtime = preload("res://scripts/worlds/world_runtime.gd")
const VM = preload("res://scripts/worlds/world_script_vm.gd")
var passed := 0
var failed := 0

func _initialize():
	call_deferred("run")

func check(condition: bool, label: String):
	if condition:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		print("FAIL: ", label)

func store_for(owner: String, url: String, temporary: bool = false):
	var store = Store.new()
	check(store.configure(owner, url, temporary), "configure isolated store: " + owner + " / " + url)
	return store

func test_storage():
	var store = store_for("player-a", "https://example.test/ember-crypt")
	var candidate = {"schema_version": 1, "lifetime_xp": 120, "player_level": 2, "unlocks": ["amber"]}
	check(store.commit(candidate), "progression commits to real local JSON")
	candidate.unlocks.append("not-saved")
	check(store.values.unlocks == ["amber"], "commit detaches nested values from caller")
	var restored = store_for("player-a", "https://example.test/ember-crypt")
	check(restored.values.lifetime_xp == 120 and restored.values.unlocks == ["amber"], "new service restores XP and unlocks")
	check(store.path == restored.path, "same player and URL reuse the save namespace")
	var other_player = store_for("player-b", "https://example.test/ember-crypt")
	var other_world = store_for("player-a", "https://example.test/another-world")
	check(other_player.values.is_empty() and other_player.path != store.path, "different player cannot see progression")
	check(other_world.values.is_empty() and other_world.path != store.path, "different world URL cannot see progression")
	var before = store.values.duplicate(true)
	var bytes_before = FileAccess.get_file_as_bytes(store.path)
	check(not store.commit({"lifetime_xp": 999}), "rapid second write is throttled")
	check(store.values == before and FileAccess.get_file_as_bytes(store.path) == bytes_before, "throttled write changes neither memory nor disk")
	# Exercise quota independently of disk throttling; no sleeps or forged clocks.
	var volatile = store_for("temporary", "world", true)
	check(volatile.commit(before) and volatile.path.is_empty(), "temporary identity has no filesystem save path")
	check(not volatile.commit({"large": "x".repeat(17000)}) and volatile.values == before, "oversized record rejected without losing progress")
	var too_many = {}
	for index in 129:
		too_many[str(index)] = index
	check(not volatile.commit(too_many) and volatile.values == before, "more than 128 keys rejected")
	check(volatile.commit({"lifetime_xp": 121}) and volatile.commit({"lifetime_xp": 122}), "memory-only progress does not need disk throttling")
	var fresh_temporary = store_for("temporary", "world", true)
	check(fresh_temporary.values.is_empty(), "temporary progress does not survive a fresh service")
	var invalid = Store.new()
	check(not invalid.configure("", "world") and not invalid.commit(before), "missing owner cannot write")
	check(not invalid.configure("owner", "") and not invalid.commit(before), "missing world URL cannot write")

func test_preservation():
	for kind in ["corrupt", "oversized", "future"]:
		var seed = store_for("recovery-" + kind, "world")
		check(seed.commit({"schema_version": 1}), "prepare " + kind + " recovery file")
		# Valid JSON of the wrong shape exercises corruption without Godot's
		# JSON.parse_string emitting an engine ERROR (an infrastructure failure).
		var original = "[]" if kind == "corrupt" else "x".repeat(17000)
		if kind == "future":
			original = '{"schema_version":999,"lifetime_xp":321}'
		var file = FileAccess.open(seed.path, FileAccess.WRITE)
		file.store_string(original)
		file.close()
		var restored = Store.new()
		var loaded = restored.configure("recovery-" + kind, "world")
		if kind == "future":
			check(loaded and restored.values.schema_version == 999, "generic store retains unknown game schema without migrating it")
		else:
			check(not loaded and not restored.writable and not restored.last_error.is_empty(), kind + " save fails closed with diagnostic")
			check(not restored.commit({"schema_version": 1}), kind + " save cannot be silently replaced")
		check(FileAccess.get_file_as_string(seed.path) == original, kind + " original bytes preserved")

func test_vm_permissions():
	var operation = {"op": "save_add", "key": "lifetime_xp", "value": 5}
	check(not VM.new().run_event([operation], {}).ok, "XP write denied without storage.local")
	check(VM.new().run_event([operation], {"capabilities": ["storage.local"]}).ok, "declared bounded XP write accepted")
	check(not VM.new().run_event([{"op": "if_saved", "key": "level", "equals": 999, "then": [{"op": "unsafe_hidden"}]}], {"capabilities": ["storage.local"], "saved": {}}).ok, "unselected saved-progress branch cannot hide forbidden code")

func runtime_for(world: Node3D, store, operations: Array):
	var entities = {}
	for station in ["camp", "shrine", "chapel", "crypt"]:
		entities[station] = {"path": station, "script": "progress"}
	var runtime = Runtime.new()
	runtime.local_store = store
	check(runtime.configure(world, {"manifest": {"script_capabilities": ["storage.local", "entity.visual"]}, "entities": entities, "programs": {"progress": {"events": {"use": operations}}}}).ok, "configure real runtime with four station entities")
	return runtime

func test_shared_stations():
	var world = Node3D.new()
	root.add_child(world)
	for station in ["camp", "shrine", "chapel", "crypt"]:
		var node = Node3D.new()
		node.name = station
		world.add_child(node)
	var store = store_for("station-player", "world", true)
	var runtime = runtime_for(world, store, [{"op": "save_add", "key": "lifetime_xp", "value": 5}])
	var expected = 0
	for station in ["camp", "shrine", "chapel", "crypt"]:
		expected += 5
		check(runtime.dispatch("use", station).ok and store.values.lifetime_xp == expected, station + " dispatch uses the same progression store")
	var before = store.values.duplicate(true)
	check(not runtime.dispatch("use", "foreign_station").ok and store.values == before, "foreign station rejected without changing progress")
	runtime.stop_scripts()
	check(not runtime.dispatch("use", "camp").ok and store.values == before, "stopped runtime cannot award XP")
	runtime.free()
	# Invalid numeric update must roll back earlier visual/save commands.
	store.commit({"lifetime_xp": "invalid-counter"})
	runtime = runtime_for(world, store, [
		{"op": "command", "capability": "entity.visual", "entity": "camp", "property": "visible", "value": false},
		{"op": "save_set", "key": "player_level", "value": 9},
		{"op": "save_add", "key": "lifetime_xp", "value": 5},
	])
	check(not runtime.dispatch("use", "camp").ok, "invalid XP type rejects whole event")
	check(world.get_node("camp").visible and store.values == {"lifetime_xp": "invalid-counter"}, "rejected event applies neither visual nor partial progression changes")
	runtime.free()
	# Simulate an unwritable store without touching permissions or real user files.
	store.writable = false
	runtime = runtime_for(world, store, [
		{"op": "command", "capability": "entity.visual", "entity": "camp", "property": "visible", "value": false},
		{"op": "save_set", "key": "player_level", "value": 2},
	])
	check(not runtime.dispatch("use", "camp").ok and world.get_node("camp").visible and not store.values.has("player_level"), "failed commit prevents dependent scene changes")
	runtime.free()
	world.free()

func run():
	test_storage()
	test_preservation()
	test_vm_permissions()
	test_shared_stations()
	print("Roguelike foundations: %s passed, %s failed" % [passed, failed])
	print("NOT COVERED: real map, enemy AI/damage, XP thresholds, upgrade UI, rig animations, renderer or XR.")
	quit(1 if failed else 0)

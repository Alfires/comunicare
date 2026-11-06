extends SceneTree
var failed := 0

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	print("PASS: " if value else "FAIL: ", title)
	if not value: failed += 1

func run():
	var runtime = load("res://scripts/worlds/world_runtime.gd").new()
	var world = Node3D.new()
	root.add_child(world)
	world.add_child(runtime)
	var target = Node3D.new()
	target.name = "Target"
	world.add_child(target)
	var store = load("res://scripts/worlds/world_local_store.gd").new()
	store.configure("audit", "world", true)
	runtime.local_store = store
	runtime.configure(world, {"manifest": {"script_capabilities": ["state.local", "storage.local"]}, "entities": {"target": {"path": "Target", "script": "logic"}}, "programs": {"logic": {"events": {"use": [{"op": "state_add", "key": "uses", "value": 1}]}}}})
	runtime.run_state = {"counter": 9223372036854775807}
	check(not runtime._run([{"op": "state_add", "key": "counter", "value": 1}]).ok and runtime.run_state.counter == 9223372036854775807, "run counters reject signed integer overflow atomically")
	store.values = {"counter": 9223372036854775807}
	check(not runtime._run([{"op": "save_add", "key": "counter", "value": 1}]).ok and store.values.counter == 9223372036854775807, "saved counters reject signed integer overflow atomically")
	runtime.run_state = {}
	var unicode_state = [{"op": "state_set", "key": "a", "value": "界".repeat(4000)}, {"op": "state_set", "key": "b", "value": "界".repeat(4000)}]
	check(not runtime._run(unicode_state).ok and runtime.run_state.is_empty(), "run state quota counts UTF-8 bytes rather than characters")
	var schema = load("res://scripts/worlds/world_ui_schema.gd")
	for prefix in ["state.", "saved."]:
		var document = {"version": 1, "pages": {"main": {"title": "Audit", "widgets": [{"id": "value", "type": "text", "bind": prefix + "x".repeat(64)}]}}}
		check(schema.validate(document, [], []).ok, "UI accepts full 64-character " + prefix + "key")
	for binding in ["state.", "typo.score"]:
		var document = {"version": 1, "pages": {"main": {"title": "Audit", "widgets": [{"id": "value", "type": "text", "bind": binding}]}}}
		check(not schema.validate(document, [], []).ok, "UI rejects unresolvable binding: " + binding)
	runtime.programs.logic.events.tick = [{"op": "state_add", "key": "ticks", "value": 1}]
	for frame in 10: runtime._process(0.03)
	check(runtime.run_state.get("ticks") == 6, "20 Hz tick retains elapsed remainder across render frames")
	target.free()
	check(not runtime.dispatch("use", "target").ok and not runtime.run_state.has("uses"), "events reject destroyed entity handles before mutating state")
	# A still-live page must not dispatch after its world has been destroyed.
	world.remove_child(runtime)
	root.add_child(runtime)
	var menu = Control.new()
	runtime.add_child(menu)
	runtime.menu = menu
	runtime.entities["target"] = weakref(runtime)
	world.free()
	check(not runtime.dispatch_ui("target", [{"op": "state_set", "key": "orphan", "value": true}], menu).ok and not runtime.run_state.has("orphan"), "UI rejects actions after its owning world is destroyed")
	runtime.free()
	await process_frame
	print("Runtime audit failures: ", failed)
	quit(1 if failed else 0)

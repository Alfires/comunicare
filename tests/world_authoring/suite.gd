extends SceneTree
## Proposed seams; missing implementation fails, never replaced by fixture logic.
const BASE = "res://addons/comunicare_world_tools/"
var passed := 0
var failed := 0
var blocked := 0

func _initialize(): call_deferred("run")

func check(ok: bool, title: String):
	print("PASS: " if ok else "FAIL: ", title)
	if ok: passed += 1
	else: failed += 1

func component(file: String, methods: Array):
	if not ResourceLoader.exists(BASE + file):
		check(false, "production authoring component exists: " + file)
		blocked += 1
		return null
	var script = load(BASE + file)
	if script == null or not script.can_instantiate():
		check(false, "authoring component instantiates: " + file)
		blocked += 1
		return null
	var service = script.new()
	for method in methods:
		if not service.has_method(method):
			check(false, file + " implements " + method)
			blocked += 1
			if service is Node: service.free()
			return null
	if service is Node: root.add_child(service)
	return service

func dispose(service):
	if service is Node: service.free()

func ok(result: Variant) -> bool:
	return result is Dictionary and result.get("ok", false) == true

func project_document() -> Dictionary:
	return {"schema": 1, "world_id": "4aa3a976-15cf-4d85-bd41-5677a12abcde", "title": "Authoring test",
		"entities": [{"id": "spawn", "name": "Spawn", "type": "spawn", "position": [0, 1, 0]},
			{"id": "cube", "name": "Cube", "type": "pickup", "position": [0, 1, -2], "collider": {"type": "box", "size": [1, 1, 1]}}],
		"assets": [], "behaviors": [], "capabilities": []}

func run():
	test_plugin_descriptor()
	test_document()
	test_interactions()
	test_entity_fields()
	await test_compiler()
	test_playtest_plan()
	test_optimizer()
	print("World authoring: %s passed, %s failed; %s dependent groups BLOCKED" % [passed, failed, blocked])
	quit(1 if failed else 0)

func test_plugin_descriptor():
	var config = ConfigFile.new()
	if config.load(BASE + "plugin.cfg") != OK:
		check(false, "Godot plugin descriptor exists")
		blocked += 1
		return
	var entry = str(config.get_value("plugin", "script", ""))
	check(not str(config.get_value("plugin", "name", "")).is_empty(), "plugin has display name")
	check(not entry.is_empty() and not entry.is_absolute_path() and not ".." in entry and FileAccess.file_exists(BASE + entry), "plugin entry stays within addon directory")
	# Actual enable/disable and dock input require a later editor integration gate.

func test_document():
	var service = component("authoring_document.gd", ["validate", "save_project", "load_project"])
	if service == null: return
	var document = project_document()
	check(ok(service.validate(document)), "minimal spawn/pickup authoring document validates")
	var duplicate = document.duplicate(true)
	duplicate.entities[1].id = "spawn"
	check(not ok(service.validate(duplicate)), "duplicate stable IDs rejected")
	var newer = document.duplicate(true)
	newer.schema = 999
	check(not ok(service.validate(newer)), "unsupported future schema fails closed")
	var dangling = document.duplicate(true)
	dangling.behaviors = [{"entity": "missing", "event": "use", "actions": []}]
	check(not ok(service.validate(dangling)), "dangling behavior owner rejected")
	check(ok(service.save_project(document, "user://project.json")), "project saves in isolated user directory")
	var restored = service.load_project("user://project.json")
	check(ok(restored) and restored.get("document", {}).get("world_id") == document.world_id, "project ID survives save/reopen")
	var original = FileAccess.get_file_as_bytes("user://project.json")
	check(not ok(service.save_project(newer, "user://project.json")) and FileAccess.get_file_as_bytes("user://project.json") == original,
		"invalid save never replaces valid project bytes")
	dispose(service)

func test_interactions():
	var service = component("interaction_tools.gd", ["make_pickup", "bind_behavior", "duplicate_entity"])
	if service == null: return
	var document = project_document()
	var before = document.duplicate(true)
	var result = service.make_pickup(document, "cube")
	check(ok(result) and document == before, "pickup tool returns draft without mutating source")
	check(not ok(service.make_pickup(document, "missing")), "pickup tool rejects unknown target")
	var bound = service.bind_behavior(document, "cube", "use", [{"op": "command", "capability": "entity.visual", "entity": "cube", "property": "visible", "value": false}])
	check(ok(bound), "supported visual behavior binds to stable entity")
	check(not ok(service.bind_behavior(document, "cube", "use", [{"op": "os.execute"}])), "unsupported native behavior cannot be authored as portable script")
	var copied = service.duplicate_entity(document, "cube")
	check(ok(copied) and copied.get("entity_id", "") not in ["", "cube", "spawn"] and document == before, "duplicate gets fresh ID without changing original")
	dispose(service)

func test_entity_fields():
	var service = component("entity_tools.gd", ["update_entity", "delete_entity"])
	if service == null: return
	var source = project_document()
	var before = source.duplicate(true)
	var result = service.update_entity(source, "cube", "Renamed", [2, 1, -3], [2, 2, 2])
	check(ok(result) and source == before and result.document.entities[1].id == "cube", "inspector edit preserves stable ID and source document")
	check(not ok(service.update_entity(source, "cube", "Invalid", [NAN, 0, 0], [1, 1, 1])), "inspector rejects invalid transform")
	check(not ok(service.delete_entity(source, "spawn")), "sole spawn is protected from deletion")
	var bound = preload("res://addons/comunicare_world_tools/interaction_tools.gd").new().bind_behavior(source, "cube", "use", [])
	check(not ok(service.delete_entity(bound.document, "cube")), "deletion cannot silently drop script bindings")
	check(ok(service.delete_entity(source, "cube")) and source == before, "unreferenced entity deletes as a validated draft")
	dispose(service)

func test_compiler():
	var service = component("world_exporter.gd", ["export_package"])
	if service == null: return
	var result = await service.export_package(project_document(), "user://export.cworld")
	check(ok(result), "compiler exports minimal playable package")
	if ok(result):
		var built = load("res://scripts/worlds/world_builder.gd").new().build_package("user://export.cworld")
		check(ok(built), "exported bytes pass production package reader and builder")
		if ok(built):
			var scene = built.scene.instantiate()
			check(scene.find_children("*", "CharacterBody3D", true, false).is_empty(), "export contains no preview player")
			scene.free()
		var original = FileAccess.get_file_as_bytes("user://export.cworld")
		var unsafe = project_document()
		unsafe.assets.append({"id": "escape", "path": "../private.key"})
		check(not ok(await service.export_package(unsafe, "user://export.cworld")) and FileAccess.get_file_as_bytes("user://export.cworld") == original,
			"unsafe export cannot overwrite last working package")
	dispose(service)

func test_playtest_plan():
	var service = component("playtest_launcher.gd", ["plan"])
	if service == null: return
	for mode in ["desktop", "vr"]:
		var result = service.plan("user://export.cworld", mode, 2)
		check(ok(result), "playtest accepts mode: " + mode)
		if not ok(result): continue
		var clients = result.get("clients", [])
		check(clients.size() == 2, "two-client plan contains two launches")
		if clients.size() == 2:
			check(clients[0].get("user_data", "") != clients[1].get("user_data", "") and not str(clients[0].get("user_data", "")).is_empty(), "playtest identities/data roots are distinct")
		for client in clients:
			check(client.get("temporary_identity", false) and client.get("microphone_muted", false), "playtest isolates identity and starts muted")
	check(not ok(service.plan("user://export.cworld", "unknown", 2)), "unknown playtest mode rejected")
	dispose(service)

func test_optimizer():
	var service = component("world_optimizer.gd", ["analyze", "optimize"])
	if service == null: return
	var document = project_document()
	var original = document.duplicate(true)
	var report = service.analyze(document)
	check(ok(report) and document == original, "optimization analysis never changes source")
	var optimized = service.optimize(document, {"preset": "balanced", "preserve_interactions": true})
	check(ok(optimized) and document == original, "optimization creates reversible derived output")
	if ok(optimized):
		var derived = optimized.get("document", {})
		check(derived.get("entities", []).any(func(entity): return entity.get("id") == "cube" and entity.get("type") == "pickup"), "optimization preserves pickup entity and ID")
		check(derived.get("behaviors") == original.behaviors, "optimization preserves script bindings")
	check(not ok(service.optimize(document, {"preset": "unknown"})), "invalid optimization preset rejected")
	dispose(service)

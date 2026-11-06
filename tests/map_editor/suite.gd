extends SceneTree
## Proposed production seams; no collaboration/editor implementation in fixtures.
const BASE = "res://scripts/editor/"
var passed := 0
var failed := 0
var blocked := 0
const OWNER = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const EDITOR = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const VIEWER = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

func _initialize(): call_deferred("run")
func check(value: bool, title: String):
	print("PASS: " if value else "FAIL: ", title)
	if value: passed += 1
	else: failed += 1

func ok(value: Variant) -> bool:
	return value is Dictionary and value.get("ok", false) == true

func component(file: String, methods: Array):
	if not ResourceLoader.exists(BASE + file):
		check(false, "production map editor component exists: " + file)
		blocked += 1
		return null
	var script = load(BASE + file)
	if script == null or not script.can_instantiate():
		check(false, "component instantiates: " + file)
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

func document() -> Dictionary:
	return {"schema": 1, "world_id": "4aa3a976-15cf-4d85-bd41-5677a12abcde", "title": "Editor test", "revision": 0,
		"entities": [{"id": "spawn", "name": "Spawn", "type": "spawn", "position": [0, 1, 0]},
			{"id": "cube", "name": "Cube", "type": "pickup", "position": [0, 1, -2], "collider": {"type": "box", "size": [1, 1, 1]}}],
		"assets": [], "behaviors": [], "capabilities": []}

func move_operation(id: String, revision: int = 0) -> Dictionary:
	return {"id": id, "generation": "session-a", "revision": revision, "op": "set_transform", "entity": "cube", "position": [1, 1, -2]}

func run():
	test_projects()
	test_commands()
	test_permissions()
	test_ordering()
	test_leases()
	test_input()
	await test_playtest()
	print("Map editor: %s passed, %s failed; %s dependent groups BLOCKED" % [passed, failed, blocked])
	quit(1 if failed else 0)

func test_projects():
	var service = component("project_store.gd", ["save_project", "load_project", "recover_project"])
	if service == null: return
	var original = document()
	check(ok(service.save_project(original, "user://map.json")), "local editor project saves")
	var loaded = service.load_project("user://map.json")
	check(ok(loaded) and loaded.get("document") == original, "saved project round trips stable IDs and revision")
	var bytes = FileAccess.get_file_as_bytes("user://map.json")
	var invalid = original.duplicate(true)
	invalid.schema = 999
	check(not ok(service.save_project(invalid, "user://map.json")) and FileAccess.get_file_as_bytes("user://map.json") == bytes, "future schema cannot overwrite existing source")
	# Interrupted write leaves an invalid temporary file, not a new authority.
	var pending = FileAccess.open("user://map.json.tmp", FileAccess.WRITE)
	pending.store_string("{unfinished")
	pending.close()
	var recovered = service.recover_project("user://map.json")
	check(ok(recovered) and recovered.get("document") == original, "recovery ignores interrupted temporary write and preserves valid source")
	dispose(service)

func test_commands():
	var service = component("edit_commands.gd", ["apply_operation", "undo_operation"])
	if service == null: return
	var source = document()
	var before = source.duplicate(true)
	var result = service.apply_operation(source, move_operation("move-1"))
	check(ok(result) and source == before, "edit returns derived document without changing source")
	if ok(result):
		var edited = result.get("document", {})
		check(edited.get("revision") == 1 and edited.get("entities", []).any(func(e): return e.id == "cube" and e.position == [1, 1, -2]), "transform edit advances revision and exact target only")
		var undone = service.undo_operation(edited, result.get("inverse", {}))
		check(ok(undone) and undone.get("document", {}).get("entities") == source.entities, "undo restores transform without deleting entities")
		var stale = service.apply_operation(edited, move_operation("move-2", 0))
		check(not ok(stale), "stale edit revision cannot overwrite newer state")
	var unknown = move_operation("bad")
	unknown.entity = "outside-world"
	check(not ok(service.apply_operation(source, unknown)), "unknown entity cannot be edited")
	var invalid = move_operation("nan")
	invalid.position = [NAN, 0, 0]
	check(not ok(service.apply_operation(source, invalid)), "nonfinite transform rejected")
	check(not ok(service.apply_operation(source, {"op": "execute", "script": "user://evil.gd"})), "edit protocol cannot execute code")
	dispose(service)

func test_permissions():
	var service = component("edit_authority.gd", ["configure", "admit", "revoke", "submit", "snapshot"])
	if service == null: return
	service.configure(document(), OWNER, "session-a")
	check(not ok(service.submit(EDITOR, move_operation("uninvited"))), "friend/account presence alone grants no editing access")
	check(ok(service.admit(OWNER, EDITOR, "editor")), "owner grants explicit editor role")
	check(ok(service.admit(OWNER, VIEWER, "viewer")), "owner grants viewer role")
	check(not ok(service.submit(VIEWER, move_operation("viewer"))), "viewer edits denied")
	check(not ok(service.admit(EDITOR, VIEWER, "owner")), "editor cannot promote another user to owner")
	check(ok(service.submit(EDITOR, move_operation("allowed"))), "admitted editor can submit valid operation")
	service.revoke(OWNER, EDITOR)
	check(not ok(service.submit(EDITOR, move_operation("revoked", 1))), "revocation blocks subsequent edits immediately")
	dispose(service)

func test_ordering():
	var service = component("edit_authority.gd", ["configure", "submit", "snapshot"])
	if service == null: return
	service.configure(document(), OWNER, "session-a")
	var stale_session = move_operation("old")
	stale_session.generation = "retired-session"
	check(not ok(service.submit(OWNER, stale_session)), "old session generation cannot mutate current project")
	var operation = move_operation("once")
	check(ok(service.submit(OWNER, operation)), "authority commits valid operation")
	var state = service.snapshot(OWNER)
	service.submit(OWNER, operation)
	check(service.snapshot(OWNER) == state, "duplicate operation delivery never increments revision twice")
	check(not ok(service.submit(OWNER, move_operation("conflict", 0))) and service.snapshot(OWNER) == state, "conflicting stale edit rejected without state mutation")
	check(not ok(service.snapshot(VIEWER)), "unadmitted client cannot download project snapshot")
	dispose(service)

func test_leases():
	var service = component("edit_leases.gd", ["acquire", "release", "disconnect_member", "expire"])
	if service == null: return
	check(ok(service.acquire("session-a", "cube", EDITOR, 1000, 2000)), "first editor gets bounded manipulation lease")
	check(not ok(service.acquire("session-a", "cube", OWNER, 1001, 2000)), "two editors cannot manipulate same entity concurrently")
	check(not ok(service.release("session-a", "cube", OWNER)), "nonholder cannot release another user's lease")
	service.disconnect_member(EDITOR)
	check(ok(service.acquire("session-a", "cube", OWNER, 1002, 2000)), "disconnect releases manipulation lease")
	service.expire(4000)
	check(ok(service.acquire("session-a", "cube", EDITOR, 4001, 2000)), "expired lease can be reacquired")
	check(not ok(service.acquire("session-a", "cube", VIEWER, 4002, 999999999)), "unbounded lease duration rejected")
	var before = service.leases.duplicate(true)
	check(not ok(service.acquire("", "cube", VIEWER, 999999, 1)) and service.leases == before, "invalid acquisition cannot expire another editor's valid lease")
	check(not ok(service.acquire("session-a", "negative", VIEWER, -1, 100)), "negative lease timestamp cannot create immediately invalid ownership")
	dispose(service)

func test_input():
	var service = component("editor_input.gd", ["transform_operation"])
	if service == null: return
	var desktop = service.transform_operation("desktop", "cube", [1, 2, 3], [0, 0, 0], [1, 1, 1], false)
	var vr = service.transform_operation("vr", "cube", [1, 2, 3], [0, 0, 0], [1, 1, 1], false)
	check(ok(desktop) and ok(vr) and desktop.get("operation") == vr.get("operation"), "desktop and VR input produce same canonical edit")
	check(not ok(service.transform_operation("vr", "cube", [1, 2, 3], [0, 0, 0], [1, 1, 1], true)), "blocked/tracking-lost editor input emits no transform")
	check(not ok(service.transform_operation("desktop", "cube", [1, 2, 3], [0, 0, 0], [0, 1, 1], false)), "singular object scale rejected")
	dispose(service)

func test_playtest():
	var service = component("editor_playtest.gd", ["prepare", "restore"])
	if service == null: return
	var source = document()
	var before = source.duplicate(true)
	var result = await service.prepare(source, "desktop", "user://playtest.cworld")
	check(ok(result) and source == before, "playtest exports immutable snapshot without mutating editor source")
	if ok(result):
		check(result.get("temporary_progress", false), "playtest cannot overwrite real world progress")
		var built = load("res://scripts/worlds/world_builder.gd").new().build_package("user://playtest.cworld")
		check(ok(built), "playtest output loads through production package boundary")
		var restored = service.restore(result.get("token", ""))
		check(ok(restored) and restored.get("document") == before, "return from playtest restores original authoring state")
	dispose(service)

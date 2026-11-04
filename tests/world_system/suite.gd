extends SceneTree
## Proposed acceptance interfaces, not production implementations or substitutes.
var passed := 0
var failed := 0
var blocked: Array[String] = []

func _initialize():
	call_deferred("run")

func check(value: bool, title: String):
	if value:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func component(file: String, methods: Array):
	var path = "res://scripts/worlds/" + file + ".gd"
	if not ResourceLoader.exists(path):
		check(false, "missing production component: " + path)
		blocked.append(file)
		return null
	var script = load(path)
	if script == null or not script.can_instantiate():
		check(false, "instantiable production component: " + path)
		blocked.append(file)
		return null
	var object = script.new()
	for method in methods:
		if not object.has_method(method):
			check(false, path + " implements " + method)
			blocked.append(file)
			dispose(object)
			return null
	return object

func dispose(object):
	if object is Node:
		object.free()

func ok(result: Variant) -> bool:
	return result is Dictionary and result.get("ok", false) == true

func rejected(result: Variant) -> bool:
	return result is Dictionary and result.get("ok", true) == false and result.get("error", "") is String and not result.get("error", "").is_empty()

func run():
	test_packages()
	test_builder()
	test_extensions()
	test_scripts()
	test_interaction()
	test_replication()
	test_moderation()
	check(not FileAccess.file_exists("user://WORLD_SCRIPT_EXECUTED"), "fixture execution sentinel absent (harness check only when reader is blocked)")
	print("\nWorld acceptance: %s passed, %s failed; %s prerequisite groups BLOCKED: %s" % [passed, failed, blocked.size(), ", ".join(blocked)])
	print("Blocked behavioral groups are NOT executed or passed. No XR/render/security certification.")
	quit(1 if failed else 0)

func inspect(reader, name: String, options: Dictionary = {}) -> Variant:
	return reader.inspect_package("res://packages/" + name + ".zip", options)

func test_packages():
	var reader = component("world_package_reader", ["inspect_package"])
	if reader == null: return
	var valid = inspect(reader, "valid")
	if not ok(valid): print("Package diagnostic: ", valid)
	check(ok(valid), "manual ZIP of native Godot scenes/materials is accepted without project, plugin or cache")
	if ok(valid):
		check(valid.get("revision", "") == FileAccess.get_file_as_string("res://packages/expected_revision.txt"), "revision is SHA-256 of exact archive bytes")
		var document: Dictionary = valid.get("document", {})
		check(document.get("entities", {}).get("item", {}).get("pickup", false) == true, "Godot node metadata preserves stable pickup identity")
		var material: Dictionary = document.get("materials", {}).get("materials/surface.tres", {})
		for channel in ["albedo", "normal", "roughness", "metallic", "ao", "emission"]:
			check(material.get("textures", {}).get(channel, "") == "textures/pixel.png", "native material retains " + channel + " texture dependency")
		check(material.get("uv1_scale", []) == [2.0, 3.0, 1.0], "UV tiling survives static material parsing")
		check(is_equal_approx(float(material.get("metallic", -1)), 0.7) and is_equal_approx(float(material.get("roughness", -1)), 0.3), "PBR scalar properties survive parsing")
	for name in ["traversal", "absolute", "backslash", "symlink", "case_collision", "duplicate_entry", "truncated", "missing_texture", "missing_instance", "unsupported_schema", "duplicate_keys", "nonfinite", "unknown_node", "wrong_property_type", "bad_constructor", "resource_cycle", "huge_mesh", "bad_texture", "forged_deflate", "external_texture", "shader", "attached_script", "method_track", "signal_method", "native_extension", "project_autoload"]:
		check(rejected(inspect(reader, name)), "reject hostile/unsupported package with diagnostic: " + name)
	check(rejected(inspect(reader, "expanded_limit", {"max_expanded_bytes": 65536})), "expanded-size budget rejects compressed payload")
	check(rejected(inspect(reader, "broken_deflate")), "malformed deflate fails as data rejection without engine errors")
	check(rejected(inspect(reader, "valid", {"max_entries": 2})), "entry count budget enforced")
	check(rejected(inspect(reader, "texture_dimensions", {"max_texture_dimension": 0})), "decoded texture dimension budget enforced")
	for name in ["terrain_required", "terrain_missing_data", "terrain_code_url"]:
		check(rejected(inspect(reader, name)), "default reader cannot bypass uninstalled addon requirement: " + name)
	check(ok(inspect(reader, "valid")), "failed inspections cannot poison subsequent valid load")
	dispose(reader)

func test_builder():
	var builder = component("world_builder", ["build_package"])
	if builder == null: return
	var built = builder.build_package("res://packages/valid.zip")
	check(ok(built) and built.get("scene") is PackedScene, "safe builder produces an application-owned scene from package data")
	if ok(built) and built.get("scene") is PackedScene:
		var world = built.scene.instantiate()
		var mesh = world.get_node_or_null("Item/Mesh")
		check(world.get_script() == null and world.get_node("Item").get_script() == null, "constructed nodes have no downloaded scripts")
		check(mesh is MeshInstance3D and mesh.mesh is BoxMesh, "Godot authored built-in mesh is reconstructed")
		if mesh is MeshInstance3D and mesh.mesh is BoxMesh:
			var material = mesh.mesh.material
			check(material is StandardMaterial3D and material.albedo_texture is ImageTexture, "packaged PNG becomes textured standard material")
			check(material is StandardMaterial3D and material.normal_enabled and material.uv1_scale.is_equal_approx(Vector3(2, 3, 1)), "runtime material retains normal map and UV tiling")
		check(built.get("spawn_point", []) == [0.0, 1.0, 0.0], "spawn metadata resolves to authored position")
		world.free()
	check(rejected(builder.build_package("res://packages/attached_script.zip")), "safe builder rejects executable scene before construction")
	check(ok(builder.build_package("res://packages/valid.zip")), "failed build preserves ability to construct valid world")
	dispose(builder)

func test_extensions():
	var reader = component("world_extension_registry", ["validate_requirements"])
	if reader == null: return
	var requirement = {"id": "comunicare.terrain3d", "data_schema": 1, "required": true, "data": "terrain/index.json"}
	check(rejected(reader.validate_requirements([requirement], {}, ["terrain/index.json"])), "required Terrain3D integration missing: fail staging")
	var installed = {"comunicare.terrain3d": {"data_schemas": [1]}}
	check(ok(reader.validate_requirements([requirement], installed, ["terrain/index.json"])), "preinstalled reviewed Terrain3D integration accepts matching data schema")
	check(rejected(reader.validate_requirements([requirement], installed, [])), "Terrain3D declaration cannot reference missing region index")
	var newer = requirement.duplicate(true)
	newer.data_schema = 999
	check(rejected(reader.validate_requirements([newer], installed, ["terrain/index.json"])), "unknown addon data schema fails closed")
	var hostile = requirement.duplicate(true)
	hostile.library_url = "https://example.invalid/evil.so"
	check(rejected(reader.validate_requirements([hostile], installed, ["terrain/index.json"])), "metadata cannot request native code download")
	hostile = requirement.duplicate(true)
	hostile.data = "../outside.json"
	check(rejected(reader.validate_requirements([hostile], installed, ["../outside.json"])), "extension data paths cannot escape package")
	dispose(reader)

func test_scripts():
	var vm = component("world_script_vm", ["run_event"])
	if vm == null: return
	var limits = {"fuel": 100, "heap_bytes": 1024, "max_commands": 4}
	var command = {"op": "command", "capability": "entity.visual", "entity": "door", "property": "visible", "value": false}
	var context = {"capabilities": ["entity.visual"], "entities": ["door"], "generation": "g1"}
	var valid = vm.run_event([command], context, limits)
	check(ok(valid) and valid.get("commands", []).size() == 1, "restricted script can emit useful visual command")
	check(rejected(vm.run_event([command], {"capabilities": [], "entities": ["door"]}, limits)), "broker rejects missing capability")
	var forged = command.duplicate(true)
	forged.entity = "other-world-door"
	check(rejected(vm.run_event([forged], context, limits)), "broker rejects handle outside current world")
	for capability in ["os.execute", "file.read", "http.request", "account.key", "engine.call", "moderation.ban", "camera.set"]:
		var attack = command.duplicate(true)
		attack.capability = capability
		check(rejected(vm.run_event([attack], {"capabilities": [capability], "entities": ["door"]}, limits)), "manifest cannot grant forbidden API: " + capability)
	var exhausted = vm.run_event([command, {"op": "repeat", "count": 1000000000, "body": [command]}], context, limits)
	check(rejected(exhausted) and exhausted.get("commands", []).is_empty(), "fuel exhaustion aborts transaction without partial commands")
	check(rejected(vm.run_event([{"op": "allocate", "bytes": 4096}], context, limits)), "VM allocation budget rejects excessive heap request")
	check(rejected(vm.run_event([{ "op": "repeat", "count": 5, "body": [command]}], context, limits)), "command amplification respects aggregate command budget")
	check(ok(vm.run_event([command], context, limits)), "disabled/bad event cannot poison next isolated invocation")
	dispose(vm)

func envelope(kind: String, entity: String = "item", epoch: int = 0) -> Dictionary:
	return {"kind": kind, "session_id": "session-a", "revision": "hash-a", "generation": "ga", "entity": entity, "epoch": epoch, "sequence": 1}

func test_interaction():
	var service = component("world_interaction", ["configure", "apply", "snapshot", "disconnect_member"])
	if service == null: return
	service.configure({"session_id": "session-a", "revision": "hash-a", "members": {"alice": "ga", "bob": "gb"}, "items": {"item": {"pickup": true, "max_hands": 2}}})
	var grab = envelope("grab")
	grab.grip = "left"
	grab.input_mode = "vr"
	var accepted = service.apply("alice", grab)
	if not ok(accepted): print("Grab diagnostic: ", accepted)
	check(ok(accepted), "VR member can grab unheld object")
	var held: Dictionary = service.snapshot().get("items", {}).get("item", {})
	check(held.get("holder", "") == "alice" and held.get("grip", "") == "left", "snapshot carries holder and grip for remote held-item rendering")
	var epoch = int(held.get("epoch", -1))
	check(epoch > 0, "accepted grip assigns positive lease epoch")
	var desktop = envelope("grab", "item", epoch)
	desktop.generation = "gb"
	desktop.input_mode = "desktop"
	desktop.grip = "virtual"
	check(rejected(service.apply("bob", desktop)), "simultaneous desktop grab cannot steal held item")
	var forged = envelope("release", "item", epoch)
	forged.generation = "gb"
	forged.holder = "alice"
	check(rejected(service.apply("bob", forged)), "supplied holder cannot impersonate authenticated owner")
	check(rejected(service.apply("mallory", grab)), "nonmember cannot obtain lease")
	check(rejected(service.apply("alice", envelope("release", "item", 0))), "stale release cannot revoke current lease")
	var release = envelope("release", "item", epoch)
	release.sequence = 2
	check(ok(service.apply("alice", release)), "current holder can release current lease")
	desktop.epoch = int(service.snapshot().get("items", {}).get("item", {}).get("epoch", -1))
	desktop.sequence = 2
	check(ok(service.apply("bob", desktop)), "desktop virtual grip uses same item lease after release")
	service.disconnect_member("bob", "gb")
	check(service.snapshot().get("items", {}).get("item", {}).get("holder", "") == "", "holder disconnect clears indirect object reference")
	check(rejected(service.apply("bob", desktop)), "disconnected/reused connection cannot replay old grab")
	dispose(service)

func test_replication():
	var state = component("world_state_replicator", ["configure", "accept_snapshot", "apply_event", "snapshot"])
	if state == null: return
	state.configure("session-a", "hash-a", {"alice": "ga"})
	var snapshot = {"session_id": "session-a", "revision": "hash-a", "sequence": 10, "items": {"item": {"holder": "alice", "generation": "ga", "grip": "left", "epoch": 1}}}
	check(ok(state.accept_snapshot("alice", "ga", snapshot)), "late join accepts bounded same-instance held-item snapshot")
	check(state.snapshot().get("items", {}).get("item", {}).get("grip", "") == "left", "late join preserves attachment rather than only body pose")
	for field in ["session_id", "revision"]:
		var wrong = snapshot.duplicate(true)
		wrong[field] = "wrong"
		check(rejected(state.accept_snapshot("alice", "ga", wrong)), "snapshot rejects mismatched " + field)
	check(rejected(state.accept_snapshot("alice", "old-generation", snapshot)), "peer number reuse cannot authenticate old snapshot")
	var event = envelope("release", "item", 1)
	event.sequence = 11
	check(ok(state.apply_event("alice", event)), "ordered event tail applies after snapshot watermark")
	check(rejected(state.apply_event("alice", event)), "replayed event cannot apply twice")
	var gap = event.duplicate(true)
	gap.sequence = 99
	check(rejected(state.apply_event("alice", gap)), "sequence gap requires recovery, not silent divergent commit")
	check(rejected(state.accept_snapshot("alice", "ga", snapshot)), "old snapshot cannot roll state back after newer event")
	dispose(state)

func test_moderation():
	var policy = component("world_instance_policy", ["configure", "authorize", "disconnect_member", "snapshot", "can_admit"])
	if policy == null: return
	policy.configure({"members": [{"id": "creator", "generation": "gc", "order": 1}, {"id": "alice", "generation": "ga", "order": 2}, {"id": "bob", "generation": "gb", "order": 3}], "admins": ["creator"], "moderated": true, "policy_ready": {"creator": true, "alice": false, "bob": true}})
	for action in ["kick", "ban"]:
		check(policy.authorize("creator", "gc", action), "admin may " + action)
		check(not policy.authorize("bob", "gb", action), "nonadmin may not " + action)
	for action in ["spawn", "run_script", "force_update", "edit_world", "promote", "set_visibility"]:
		check(not policy.authorize("creator", "gc", action), "creator/admin has no extra power: " + action)
	policy.disconnect_member("creator", "gc")
	check(policy.snapshot().get("admins", []) == ["alice"], "last-admin departure promotes earliest remaining member")
	check(not policy.authorize("creator", "gc", "ban"), "departed creator has no retained moderation power")
	check(not policy.can_admit(), "missing successor ban policy closes new admission")
	policy.disconnect_member("alice", "ga")
	check(policy.snapshot().get("admins", []) == ["bob"] and policy.can_admit(), "next successor with complete policy can admit")
	policy.disconnect_member("bob", "gb")
	check(policy.snapshot().get("members", []).is_empty() and policy.snapshot().get("admins", []).is_empty(), "empty instance retains no members or former admins")
	dispose(policy)

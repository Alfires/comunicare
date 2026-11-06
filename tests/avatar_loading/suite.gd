extends SceneTree

var passed := 0
var failed := 0
var completed: Array = []
var world_completed: Array = []

class SizeSettings extends RefCounted:
	var values: Dictionary = {}
	func get_value(key: String): return values.get(key)

func test_size_policy():
	var policy = load("res://scripts/assets/avatar_size_policy.gd")
	var mib = 1024 * 1024
	check(policy.classify(0) == "invalid" and policy.classify(-1) == "invalid", "empty and negative avatar sizes rejected")
	check(policy.classify(256 * mib) == "allow", "exact warning threshold needs no confirmation")
	check(policy.classify(256 * mib + 1) == "warn", "large avatar warns instead of being rejected")
	check(policy.classify(1024 * mib) == "warn" and policy.classify(1024 * mib + 1) == "blocked", "1 GiB boundary is inclusive hard ceiling")
	var store = SizeSettings.new()
	store.values = {"assets.avatar_limit_mib": 128, "assets.avatar_warning_mib": 64}
	check(policy.classify(65 * mib, store) == "warn" and policy.classify(129 * mib, store) == "blocked", "configured warning and hard size used")
	store.values["assets.avatar_warning_mib"] = 256
	check(policy.limits(store).warning == 128 * mib, "warning clamps to lowered hard limit")
	store.values = {"assets.avatar_limit_mib": 99999, "assets.avatar_warning_mib": -1}
	check(policy.limits(store) == {"hard": 1024 * mib, "warning": 32 * mib}, "settings cannot bypass absolute byte ceiling or warning floor")
	store.values = {"assets.avatar_limit_mib": INF, "assets.avatar_warning_mib": NAN}
	check(policy.limits(store) == {"hard": 1024 * mib, "warning": 256 * mib}, "nonfinite settings safely use defaults")
	check(load("res://scripts/assets/asset_cache.gd").LIMITS.avatar == policy.MAX_BYTES, "cache avatar ceiling agrees with size policy")
	check(load("res://scripts/assets/asset_cache.gd").LIMITS.animation == 16 * mib, "standalone animation limit remains unchanged")
	check(not await policy.confirm(root, 257 * mib, "test-model"), "headless cannot bypass large-avatar confirmation")
	check(await policy.confirm(root, 256 * mib, "test-model"), "normal avatars need no popup")
	check(not await policy.confirm(root, 1024 * mib + 1, "test-model"), "hard cap cannot be confirmed away")

func prepare_test_world(loader):
	world_completed.append(await loader.prepare_world_async("isolated-test-package"))

func _initialize():
	call_deferred("run")

func check(ok: bool, title: String):
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func load_model(loader: Node, bytes: PackedByteArray):
	completed.append(await loader._load_model_from_buffer(bytes))

func run():
	await test_size_policy()
	var json = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}],
		"nodes": [{"name": "AvatarRoot"}]}
	var bytes = JSON.stringify(json).to_utf8_buffer()
	var loader = load("res://slow_loader.gd").new()
	root.add_child(loader)
	prepare_test_world(loader)
	var world_frames := 0
	while world_completed.is_empty():
		await create_timer(0.005).timeout
		world_frames += 1
	check(world_frames >= 10 and world_completed[0].worker, "world preparation keeps frame heartbeat responsive on worker thread")
	check(not loader.world_prepare_busy and loader.world_thread == null, "world preparation joins completed worker and releases queue")
	load_model(loader, bytes)
	load_model(loader, bytes)
	var frames := 0
	var deadline = Time.get_ticks_msec() + 5000
	while completed.size() < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.005).timeout
		frames += 1
	check(completed.size() == 2, "concurrent avatar imports finish through production loader")
	check(frames >= 10, "main-loop heartbeat continues during expensive avatar imports")
	check(not loader.avatar_import_busy and loader.avatar_thread == null, "completed worker is joined and import queue released")
	if completed.size() == 2:
		check(completed[0] is Node3D and completed[1] is Node3D, "real GLTFDocument produces usable detached models")
		if completed[0] != null and completed[1] != null:
			check(completed[0] != completed[1] and completed[0].get_parent() == null and completed[1].get_parent() == null,
				"requests own separate model trees without shared reparenting")
			check(completed[0].get_meta("worker_thread", false) and completed[1].get_meta("worker_thread", false),
				"parsing and scene construction run off the main thread")
	for model in completed:
		if is_instance_valid(model):
			model.free()
	check(await loader._load_model_from_buffer(PackedByteArray()) == null, "empty import rejected without starting worker")
	var file = FileAccess.open("res://test.vrm", FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var local = await loader._load_model_from_file("res://test.vrm")
	check(local is Node3D and local.get_parent() == null, "local VRM path uses same asynchronous detached import")
	if local != null:
		local.free()
	var packed = PackedByteArray()
	for value in [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0]:
		packed.append_array(PackedFloat32Array([value]).to_byte_array())
	var triangle = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}],
		"nodes": [{"mesh": 0}], "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}],
		"buffers": [{"uri": "data:application/octet-stream;base64," + Marshalls.raw_to_base64(packed), "byteLength": packed.size()}],
		"bufferViews": [{"buffer": 0, "byteLength": packed.size()}],
		"accessors": [{"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3", "min": [0, 0, 0], "max": [1, 1, 0]}]}
	var rendered = await loader._load_model_from_buffer(JSON.stringify(triangle).to_utf8_buffer())
	check(rendered is Node3D, "worker imports real mesh resources, not only empty node trees")
	if rendered != null:
		root.add_child(rendered)
		await process_frame
		var meshes = rendered.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty() and meshes[0].mesh.get_surface_count() == 1,
			"worker-built mesh can attach on main thread with valid geometry")
		rendered.free()
	loader.free()
	print("\nAvatar loading: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

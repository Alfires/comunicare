extends SceneTree

const Cache = preload("res://scripts/assets/asset_cache.gd")
var passed := 0
var failed := 0
var results: Array = []

func _initialize():
	call_deferred("run")

func check(value: bool, title: String):
	if value:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func validate(path: String) -> bool:
	return FileAccess.get_file_as_string(path).begins_with("valid-")

func acquire(cache: Node, url: String):
	results.append(await cache.fetch(url, "avatar", validate))

func run():
	var cache = Cache.new()
	root.add_child(cache)
	check(cache.initialize("res://cache"), "initialize isolated cache")
	cache.allow_http = true
	var base = "http://127.0.0.1:" + FileAccess.get_file_as_string("res://port.txt")
	check(not cache._allowed_url("https://user:secret@example.org/a"), "credentials rejected")
	check(not cache._allowed_url("file:///etc/passwd"), "non HTTP scheme rejected")
	check(not cache.trust_remote_worlds, "remote executable world loading requires explicit trust opt-in")
	check(cache._key(base + "/a?x=1", "avatar") != cache._key(base + "/a?x=2", "avatar"), "query parameters remain significant")
	acquire(cache, base + "/asset")
	acquire(cache, base + "/asset")
	while results.size() < 2:
		await process_frame
	check(not results[0].is_empty() and results[0].hash == results[1].hash, "coalesced real HTTP fetch returns same revision")
	var first: Dictionary = results[0]
	check(FileAccess.get_file_as_string(first.path) == "valid-revision-1", "verified source bytes persisted")
	check(cache.records.size() == 1, "source registered exactly once")
	var hit = await cache.fetch(base + "/asset", "avatar", validate)
	check(hit.hash == first.hash and not hit.stale, "fresh cache hit")
	cache.refresh_seconds = 0
	var conditional = await cache.fetch(base + "/asset", "avatar", validate)
	check(conditional.hash == first.hash and not conditional.stale, "conditional GET 304 retains verified content")
	var request = HTTPRequest.new()
	root.add_child(request)
	request.request(base + "/advance")
	await request.request_completed
	request.queue_free()
	var changes: Array = []
	cache.revision_available.connect(func(source, previous, revision): changes.append([source, previous, revision]))
	var updated = await cache.fetch(base + "/asset", "avatar", validate)
	check(updated.hash != first.hash and FileAccess.get_file_as_string(updated.path) == "valid-revision-2", "same URL update downloads new immutable revision")
	check(changes.size() == 1 and changes[0][1] == first.hash, "accepted update emits old and new revision")
	check(FileAccess.get_file_as_string(first.path) == "valid-revision-1", "active previous bytes never overwritten")
	var invalid = await cache.fetch(base + "/bad", "avatar", validate)
	check(invalid.is_empty(), "invalid content is not published")
	var private_asset = await cache.fetch(base + "/private", "avatar", validate)
	var private_path: String = private_asset.path
	check(not cache.records.has(cache._key(base + "/private", "avatar")), "no-store response excluded from persistent index")
	private_asset.clear()
	await process_frame
	check(not FileAccess.file_exists(private_path), "no-store temporary removed after final lease")
	var copy = Cache.new()
	root.add_child(copy)
	check(copy.initialize("res://cache"), "index survives new service instance")
	copy.allow_http = true
	var restarted = await copy.fetch(base + "/asset", "avatar", validate)
	check(restarted.hash == updated.hash, "persistent hit after restart")
	copy.free()
	var file = FileAccess.open("res://local.vrma", FileAccess.WRITE)
	file.store_string("valid-local-motion")
	file.close()
	var imported = await cache.import_file("res://local.vrma", "animation", validate)
	check(not imported.is_empty(), "local import stored as pinned managed original")
	cache.clear_unused()
	check(FileAccess.file_exists(first.path) and FileAccess.file_exists(imported.path), "clear unused preserves leases and imported originals")
	check(FileAccess.file_exists("res://local.vrma"), "external source never deleted")
	var imported_hash: String = imported.hash
	check(not cache.remove_revision(imported_hash), "explicit removal refuses an active import lease")
	cache.quota_bytes = 1
	var full = await cache.fetch(base + "/another", "avatar", validate, true)
	check(full.is_empty() and FileAccess.file_exists(imported.path), "quota exhaustion fails without deleting pinned content")
	var corrupt = Cache.new()
	root.add_child(corrupt)
	DirAccess.make_dir_recursive_absolute("res://corrupt")
	file = FileAccess.open("res://corrupt/index.json", FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	check(not corrupt.initialize("res://corrupt") and not corrupt.writable, "corrupt index preserved read-only")
	check(FileAccess.get_file_as_string("res://corrupt/index.json") == "not json", "corrupt source is not silently replaced")
	corrupt.free()
	var recover = Cache.new()
	root.add_child(recover)
	DirAccess.make_dir_recursive_absolute("res://recover")
	var intact = FileAccess.get_file_as_string("res://cache/index.json")
	file = FileAccess.open("res://recover/index.json", FileAccess.WRITE)
	file.store_string(intact + "xx")
	file.close()
	check(recover.initialize("res://recover"), "startup automatically repairs trailing index junk")
	check(JSON.parse_string(FileAccess.get_file_as_string("res://recover/index.json")) is Dictionary, "automatic repair writes valid JSON")
	var backups = Array(DirAccess.get_files_at("res://recover"))
	check(backups.any(func(name): return name.ends_with(".bak") and FileAccess.get_file_as_string("res://recover/" + name) == intact + "xx"), "automatic repair preserves exact corrupt backup")
	check(recover.records.size() == cache.records.size(), "automatic recovery preserves all records")
	check(recover.has_method("_check_index_health"), "cache has background integrity check")
	if recover.has_method("_check_index_health"):
		file = FileAccess.open("res://recover/index.json", FileAccess.WRITE)
		file.store_string(intact + "junk")
		file.close()
		recover._check_index_health()
		var probe = JSON.new()
		for i in 100:
			await create_timer(0.01).timeout
			if probe.parse(FileAccess.get_file_as_string("res://recover/index.json")) == OK: break
		check(probe.parse(FileAccess.get_file_as_string("res://recover/index.json")) == OK and probe.data is Dictionary, "background worker repairs later corruption without user action")
	recover.free()
	for malformed in ['{"schema":2,"sources":{}}xx', '{"schema":1,"sources":{"bad":{}}}xx', '{"schema":1,"sources":']:
		var unsafe_cache = Cache.new()
		root.add_child(unsafe_cache)
		DirAccess.make_dir_recursive_absolute("res://unsafe")
		file = FileAccess.open("res://unsafe/index.json", FileAccess.WRITE)
		file.store_string(malformed)
		file.close()
		check(not unsafe_cache.initialize("res://unsafe") and FileAccess.get_file_as_string("res://unsafe/index.json") == malformed, "ambiguous or unsupported damage is preserved without silent reset")
		unsafe_cache.free()
	results.clear()
	first.clear()
	hit.clear()
	conditional.clear()
	updated.clear()
	restarted.clear()
	imported.clear()
	await process_frame
	check(cache.remove_revision(imported_hash) and not FileAccess.file_exists(cache.blob_path(imported_hash)), "explicit removal deletes released managed import")
	cache.queue_free()
	await process_frame
	print("\nAsset cache: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

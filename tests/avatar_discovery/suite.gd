extends SceneTree
## Proposed acceptance interfaces. Fixtures never implement feature behavior.
var passed := 0
var failed := 0
var skipped := 0
const BASE = "res://scripts/discovery/avatars/"

func _initialize(): call_deferred("run")

func check(ok: bool, title: String):
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func component(name: String, methods: Array):
	var path = BASE + name + ".gd"
	check(ResourceLoader.exists(path), "production component exists: " + name)
	if not ResourceLoader.exists(path):
		skipped += 1
		return null
	var object = load(path).new()
	for method in methods:
		if not object.has_method(method):
			check(false, name + " implements " + method)
			if object is Node: object.free()
			skipped += 1
			return null
	if object is Node: root.add_child(object)
	return object

func dispose(object):
	if object is Node: object.free()

func run():
	test_home_entry()
	test_sources()
	test_requests()
	await test_loopback_search()
	test_import_gate()
	test_browser()
	print("Avatar discovery RED: %d passed, %d failed; %d dependent groups not run" % [passed, failed, skipped])
	quit(1 if failed else 0)

func test_home_entry():
	var text = FileAccess.get_file_as_string("res://home_scene.txt")
	check('name="AvatarBrowser"' in text and 'text = "Avatar Browser"' in text,
		"real Home scene contains an Avatar Browser tile")
	check('name="WorldExplorer"' in text and 'name="ActiveInstance"' in text and 'name="Emotes"' in text,
		"existing Home navigation remains available")

func test_sources():
	var sources = component("source_registry", ["add_source", "set_credentials", "remove_source", "export_configuration", "get_credentials"])
	if sources == null: return
	var builtin = {"id": "builtin", "kind": "builtin", "base_url": "https://public.example.test", "auth": "none"}
	check(sources.add_source(builtin), "anonymous built-in source accepted")
	var forbidden = builtin.duplicate(true)
	for mode in ["bearer", "api_key", "oauth"]:
		forbidden.id = "builtin-" + mode
		forbidden.auth = mode
		check(not sources.add_source(forbidden), "built-ins reject " + mode + " authentication")
	check(not sources.set_credentials("builtin", {"token": "synthetic-secret"}), "built-in source cannot acquire credentials")
	var custom = {"id": "custom", "kind": "custom", "base_url": "https://custom.example.test", "auth": "bearer"}
	check(sources.add_source(custom), "user-added API may declare optional login")
	check(sources.set_credentials("custom", {"token": "synthetic-secret", "memory_only": true}), "custom source supports memory-only synthetic credential")
	check(not "synthetic-secret" in JSON.stringify(sources.export_configuration()), "ordinary source persistence excludes credentials")
	sources.remove_source("custom")
	check(sources.get_credentials("custom").is_empty(), "removal clears custom source credentials")
	for url in ["http://public.example.test", "https://user:password@example.test", "file:///etc/passwd"]:
		var invalid = builtin.duplicate(true)
		invalid.id = "unsafe"
		invalid.base_url = url
		check(not sources.add_source(invalid), "unsafe custom/built-in endpoint rejected: " + url.get_slice(":", 0))
	dispose(sources)

func test_requests():
	var policy = component("request_policy", ["prepare_request"])
	if policy == null: return
	var builtin = {"id": "public", "kind": "builtin", "base_url": "https://public.example.test", "auth": "none"}
	var custom = {"id": "private", "kind": "custom", "base_url": "https://private.example.test", "auth": "bearer"}
	var secret = {"token": "synthetic-secret"}
	var public_request: Dictionary = policy.prepare_request(builtin, "https://public.example.test/search", secret)
	check(not public_request.is_empty(), "public request can be constructed")
	check(not "synthetic-secret" in JSON.stringify(public_request), "built-in request never inherits custom credentials")
	var own: Dictionary = policy.prepare_request(custom, "https://private.example.test/search", secret)
	check("synthetic-secret" in JSON.stringify(own.get("headers", [])), "custom credentials are scoped to explicit source origin")
	check(policy.prepare_request(custom, "https://cdn.example.test/model.glb", secret).is_empty(), "cross-origin authenticated download denied by default")
	for url in ["https://public.example.test/model?token=secret", "https://public.example.test/model?api_key=secret"]:
		check(policy.prepare_request(builtin, url, {}).is_empty(), "token-bearing built-in URL rejected")
	dispose(policy)

func test_loopback_search():
	var service = component("discovery_service", ["configure", "search"])
	if service == null: return
	var base = "http://127.0.0.1:" + FileAccess.get_file_as_string("res://port.txt")
	# Test-only transport override; normal configuration must still require HTTPS.
	service.configure({"id": "fixture", "base_url": base, "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	var result: Dictionary = await service.search({"query": "robot", "type": "all", "cursor": ""})
	check(result.get("items", []).size() == 2, "real loopback response lists avatars and animations")
	check(result.get("next_cursor") == "page-2", "provider pagination cursor retained")
	var received: Dictionary = result.get("request_received", {})
	check(received.has("authorization") and received.authorization == "" and received.get("cookie") == "", "server observes anonymous request without auth or cookies")
	result = await service.search({"query": "robot", "type": "animation", "cursor": ""})
	check(result.get("items", []).size() == 1 and result.items[0].type == "animation", "type filter reaches real HTTP provider")
	for endpoint in ["/bad", "/rate-limit", "/login-required"]:
		service.configure({"id": "fixture", "base_url": base + endpoint, "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
		result = await service.search({"query": "", "type": "all", "cursor": ""})
		check(not result.get("error", "").is_empty(), "provider failure becomes bounded result: " + endpoint)
	dispose(service)

func test_import_gate():
	var gate = component("import_policy", ["evaluate"])
	if gate == null: return
	var record = {"type": "avatar", "format": "vrm", "compatibility": "unknown", "license": "CC0-1.0", "redistribution": true}
	check(not gate.evaluate(record).get("can_equip", true), "public metadata cannot bypass importer validation")
	record.compatibility = "verified"
	record.redistribution = false
	check(not gate.evaluate(record).get("can_equip", true), "downloadable model without redistribution cannot equip")
	record.format = "fbx"
	check(not gate.evaluate(record).get("can_import", true), "unsupported FBX is not silently accepted")
	dispose(gate)

func test_browser():
	var path = "res://scenes/GUI/avatar_browser.tscn"
	check(ResourceLoader.exists(path), "real browser scene exists")
	if not ResourceLoader.exists(path):
		skipped += 1
		return
	var browser = load(path).instantiate()
	root.add_child(browser)
	if not browser.has_method("submit_home_search") or not browser.has_method("select_category") or not browser.has_method("get_search_state"):
		check(false, "browser exposes Home search/category acceptance API")
		skipped += 1
		browser.free()
		return
	browser.submit_home_search("robot dance")
	var state: Dictionary = browser.get_search_state()
	check(state.get("tab") == "search" and state.get("query") == "robot dance", "Home submit switches to Search with exact query")
	check(state.get("cursor", "") == "", "new Home search resets pagination")
	browser.select_category("robots")
	state = browser.get_search_state()
	check(state.get("tab") == "search" and state.get("category") == "robots", "Home category opens filtered Search")
	browser.free()

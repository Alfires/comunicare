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
	if object is Node: object.queue_free()

func run():
	test_home_entry()
	test_sources()
	test_requests()
	await test_loopback_search()
	test_import_gate()
	test_advanced_filters()
	test_thumbnail_bounds()
	test_oauth()
	if FileAccess.file_exists("res://sample.vrma"):
		var reader = load("res://scripts/assets/humanoid_animation.gd").new()
		var converter = load(BASE + "animation_conversion.gd").new()
		var converted = converter.convert(FileAccess.get_file_as_bytes("res://sample.vrma"))
		check(not converted.is_empty() and not reader.read_bytes(converted).is_empty(), "explicit in-place provider animation passes production humanoid importer")
	test_browser()
	if FileAccess.file_exists("res://keyring-opt-in.txt"): await test_keyring_roundtrip()
	if FileAccess.file_exists("res://live-opt-in.txt"): await test_live_sources()
	print("Avatar discovery: %d passed, %d failed; %d dependent groups not run" % [passed, failed, skipped])
	quit(1 if failed else 0)

func test_home_entry():
	var text = FileAccess.get_file_as_string("res://home_scene.txt")
	check('name="AvatarBrowser"' in text and 'text = "Avatar Browser"' in text,
		"real Home scene contains an Avatar Browser tile")
	check('name="WorldExplorer"' in text and 'name="ActiveInstance"' in text and 'name="Emotes"' in text,
		"existing Home navigation remains available")

func test_advanced_filters():
	var path = BASE + "catalog_filters.gd"
	check(ResourceLoader.exists(path), "advanced catalog filter component exists")
	if not ResourceLoader.exists(path): return
	var filters = load(path).new()
	var records = [
		{"id": "robot", "type": "avatar", "title": "Friendly Robot", "author": "Alex", "format": "vrm", "license": "CC0-1.0", "redistribution": true, "tags": ["robot"], "category": "humanoid", "compatibility": "unknown"},
		{"id": "wave", "type": "animation", "title": "Wave", "format": "vrma", "license": "CC-BY", "redistribution": false, "tags": ["greeting"], "category": "emotes", "compatibility": "unknown", "loop": true}]
	check(filters.apply(records, {"query": "alex"}).size() == 1, "search includes author metadata")
	check(filters.apply(records, {"tag": "robot"}).size() == 1, "tag filter uses bounded catalog metadata")
	check(filters.apply(records, {"license": "CC0"}).size() == 1, "license filter distinguishes CC0 from attribution licenses")
	check(filters.apply(records, {"compatibility": "verified"}).is_empty(), "unknown assets never match verified filter")
	check(filters.apply(records, {"category": "emotes", "loop": "yes"}).size() == 1, "animation category and loop filters combine")
	check(filters.apply(records, {"shareable": "yes"}).size() == 1, "redistribution filter is independent of download availability")

func test_thumbnail_bounds():
	var path = BASE + "thumbnail_cache.gd"
	check(ResourceLoader.exists(path), "bounded thumbnail decoder exists")
	if not ResourceLoader.exists(path): return
	var cache = load(path).new()
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)
	var bytes = image.save_png_to_buffer()
	check(cache.decode(bytes) != null, "small PNG thumbnail decodes")
	var enormous = bytes.duplicate()
	# PNG IHDR width is big-endian; reject before native allocation or CRC parsing.
	enormous[16] = 0x7f
	enormous[17] = 0xff
	check(cache.decode(enormous) == null, "oversized thumbnail dimensions rejected before decode")
	check(cache.decode("not-an-image".to_utf8_buffer()) == null, "nonimage response is not rendered")
	var texture = cache.decode(bytes)
	cache.store("sample", texture)
	check(cache.get_texture("sample") == texture, "thumbnail cache reuses decoded texture")
	cache.entries.sample.at = Time.get_ticks_msec() - cache.TTL_MSEC - 1
	check(cache.get_texture("sample") == null, "expired thumbnail is not reused")

func test_oauth():
	var path = BASE + "oauth_session.gd"
	check(ResourceLoader.exists(path), "custom public-client OAuth PKCE component exists")
	if not ResourceLoader.exists(path): return
	var oauth = load(path).new()
	var config = {"authorization_url": "https://login.example.test/authorize", "token_url": "https://login.example.test/token", "client_id": "public-client", "redirect_uri": "http://127.0.0.1:43210/callback", "scope": "catalog"}
	var url: String = oauth.begin(config)
	check("code_challenge_method=S256" in url and not oauth.verifier in url, "PKCE verifier is never exposed in authorization URL")
	check(oauth.accept_callback(config.redirect_uri + "?code=fixture&state=wrong", config).is_empty(), "OAuth callback rejects wrong state")
	check(oauth.accept_callback("http://127.0.0.1:12345/callback?code=fixture&state=" + oauth.state, config).is_empty(), "OAuth callback rejects wrong loopback port")
	var callback: String = config.redirect_uri + "?code=fixture&state=" + oauth.state
	var fields: Dictionary = oauth.accept_callback(callback, config)
	check(fields.get("code") == "fixture" and fields.has("code_verifier"), "valid callback produces code exchange with verifier")
	check(oauth.accept_callback(callback, config).is_empty(), "OAuth authorization code callback cannot be replayed")
	oauth.begin(config)
	oauth.expires = Time.get_ticks_msec() - 1
	check(oauth.accept_callback(config.redirect_uri + "?code=fixture&state=" + oauth.state, config).is_empty(), "OAuth callback times out")
	var store_path = BASE + "credential_store.gd"
	check(ResourceLoader.exists(store_path), "OS credential store has explicit unavailable fallback")
	if ResourceLoader.exists(store_path):
		var store = load(store_path).new()
		check(store.has_method("available") and store.has_method("perform"), "credential store exposes capability and async operation")
		store.free()
	var registry = load(BASE + "source_registry.gd").new()
	check(registry.add_source({"id": "custom-oauth", "kind": "custom", "auth": "oauth", "base_url": "https://api.example.test/catalog", "oauth": config}), "custom source accepts public-client OAuth config")
	check(not registry.add_source({"id": "built-in-oauth", "kind": "builtin", "auth": "oauth", "base_url": "https://api.example.test/catalog", "oauth": config}), "built-in OAuth remains forbidden")
	check(not "code_verifier" in JSON.stringify(registry.export_configuration()), "OAuth session secret never enters source preferences")

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
	check(not sources.add_source({"id": "spoof", "kind": "custom", "base_url": "https://custom.example.test", "adapter": "osa"}), "custom source cannot impersonate reviewed built-in adapter")
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
	check(policy.prepare_request(custom, "https://private.example.test:444/search", secret).is_empty(), "different port cannot receive custom credential")
	for url in ["https://public.example.test/model?token=secret", "https://public.example.test/model?api_key=secret"]:
		check(policy.prepare_request(builtin, url, {}).is_empty(), "token-bearing built-in URL rejected")
	dispose(policy)

func test_loopback_search():
	var service = component("discovery_service", ["configure", "search"])
	if service == null: return
	var base = "http://127.0.0.1:" + FileAccess.get_file_as_string("res://port.txt")
	# Test-only transport override; normal configuration must still require HTTPS.
	service.configure({"id": "fixture", "base_url": base, "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	var result: Dictionary = await service.search({"query": "", "type": "all", "cursor": ""})
	check(result.get("items", []).size() == 2, "real loopback response lists avatars and animations")
	check(result.get("next_cursor") == "page-2", "provider pagination cursor retained")
	var received: Dictionary = result.get("request_received", {})
	check(received.has("authorization") and received.authorization == "" and received.get("cookie") == "", "server observes anonymous request without auth or cookies")
	result = await service.search({"query": "wave", "type": "animation", "cursor": ""})
	check(result.get("items", []).size() == 1 and result.items[0].type == "animation", "type filter reaches real HTTP provider")
	for endpoint in ["/bad", "/rate-limit", "/login-required"]:
		service.configure({"id": "fixture", "base_url": base + endpoint, "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
		result = await service.search({"query": "", "type": "all", "cursor": ""})
		check(not result.get("error", "").is_empty(), "provider failure becomes bounded result: " + endpoint)
	service.retry_at.clear() # Independent credential scenario after deliberate 429.
	service.configure({"id": "fixture", "base_url": base, "kind": "custom", "auth": "bearer"}, {"allow_loopback_http": true})
	service.credentials = {"token": "synthetic-secret"}
	result = await service.search({"query": "", "type": "all"})
	check(result.get("request_received", {}).get("authorization") == "Bearer synthetic-secret", "custom catalog receives scoped credential over real loopback")
	service.configure({"id": "fixture", "base_url": base, "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	result = await service.search({"query": "", "type": "all"})
	check(result.get("request_received", {}).get("authorization") == "", "switch back to public clears authenticated context")
	check(result.get("items", []).all(func(item): return item.get("compatibility") == "unknown"), "remote metadata cannot self-certify importer compatibility")
	service.configure({"id": "cached", "base_url": base + "/bad", "kind": "builtin", "auth": "none", "adapter": "osa"}, {"allow_loopback_http": true})
	service.catalogs.cached = {"at": Time.get_ticks_msec(), "records": [{"id": "cached", "title": "Cached robot", "type": "avatar", "format": "vrm"}]}
	result = await service.search({"query": "", "type": "all"})
	check(result.get("items", []).size() == 1, "fresh built-in metadata cache avoids network revalidation")
	service.catalogs.cached.at = Time.get_ticks_msec() - service.CATALOG_TTL_MSEC - 1
	result = await service.search({"query": "", "type": "all"})
	check(result.has("error"), "expired catalog attempts revalidation rather than serving cache forever")
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
	check(browser.filter_controls.has("license") and browser.filter_controls.has("compatibility") and browser.filter_controls.has("loop"), "advanced filter controls exist in real browser")
	var before = browser.results.get_child_count()
	browser._card({"provider": "osa", "id": "local-fixture", "title": "Fixture", "type": "avatar"})
	check(browser.results.get_child_count() == before + 1 and browser.card_buttons.has("osa:local-fixture"), "real result card provides thumbnail slot and focusable action")
	check(browser.registry.sources.has("vox") and browser.registry.sources.vox.adapter == "vox", "built-in animations-only catalog is available separately")
	check(browser.registry.sources.values().all(func(item): return item.auth == "none"), "all built-in adapters are anonymous")
	check(browser.services.is_empty(), "opening browser does not start unconsented network requests")
	browser.saved_records = [{"provider": "osa", "id": "restore", "title": "Restored", "type": "avatar"}]
	browser.return_record = "osa:restore"
	browser._restore_results()
	check(browser.card_buttons.has("osa:restore"), "Back restores existing result cards without another catalog request")
	check(browser.services.is_empty(), "restoring results never refetches catalog metadata")
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

func test_live_sources():
	var service = load(BASE + "discovery_service.gd").new()
	root.add_child(service)
	for source in [
		{"id": "osa", "kind": "builtin", "auth": "none", "adapter": "osa", "base_url": service.OSA + "avatars/100avatars-r1.json"},
		{"id": "vox", "kind": "builtin", "auth": "none", "adapter": "vox", "base_url": service.VOX + "manifest.json"}]:
		service.configure(source)
		var result: Dictionary = await service.search({"query": "", "type": "all"})
		if result.has("error"): print("LIVE diagnostic: ", result.error)
		check(not result.get("items", []).is_empty(), "LIVE anonymous production catalog works: " + source.id)
		if result.get("items", []).is_empty(): continue
		var download: Dictionary = await service.request_bytes(result.items[0].download_url, 64 * 1024 * 1024)
		check(download.has("bytes") and download.bytes.size() > 0, "LIVE production download including bounded redirects: " + source.id)
		if source.id == "vox" and download.has("bytes"):
			var converter = load(BASE + "animation_conversion.gd").new()
			check(not converter.convert(download.bytes).is_empty(), "LIVE animation converts to validated in-place humanoid clip")
	service.queue_free()

func test_keyring_roundtrip():
	var store = load(BASE + "credential_store.gd").new()
	root.add_child(store)
	var id = "isolated-test-" + str(Time.get_ticks_usec())
	var stored: Dictionary = await store.perform("store", "synthetic-test-account", id, "https://example.test", "synthetic-no-real-secret")
	check(stored.get("ok", false), "OPT-IN OS keyring stores synthetic credential")
	if stored.get("ok", false):
		var restored: Dictionary = await store.perform("lookup", "synthetic-test-account", id, "https://example.test")
		check(restored.get("ok", false) and restored.get("token") == "synthetic-no-real-secret", "OPT-IN OS keyring restores exact synthetic credential")
		var cleared: Dictionary = await store.perform("clear", "synthetic-test-account", id, "https://example.test")
		check(cleared.get("ok", false), "OPT-IN OS keyring removes synthetic test credential")
	store.queue_free()

extends SceneTree
## Proposed acceptance interfaces. Fixtures never implement feature behavior.
var passed := 0
var failed := 0
var skipped := 0
const BASE = "res://scripts/discovery/avatars/"

class DelayedKeyring extends Node:
	func perform(mode: String, _account: String, _source: String, _origin: String, _secret: String = "") -> Dictionary:
		await get_tree().process_frame
		return {"ok": true, "token": "delayed-token" if mode == "lookup" else ""}

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
	await test_content_negotiation()
	await test_audit_regressions()
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
	check('"avatars": "res://scenes/GUI/avatar_browser.tscn"' in text and '"label": "Change avatar"' in text,
		"tablet rail and Quick page both open the Avatar Browser")
	check('"worlds": "res://scenes/GUI/world_explorer.tscn"' in text and '"instance": "res://scenes/GUI/share_session_menue.tscn"' in text
		and '"label": "Emotes"' in text, "existing navigation to worlds, instance and emotes remains available")

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
	check(filters.apply([{"id": "unknown", "license": "unknown"}], {"license": "unknown"}).size() == 1, "unknown license filter accepts lowercase provider label")
	check(filters.apply(records, {"tag": "rob"}).is_empty(), "tag filter matches whole tags rather than substrings")
	var misleading = records[0].duplicate(true)
	misleading.license = "CC0-not-actually-a-license"
	check(filters.apply([misleading], {"license": "CC0"}).is_empty(), "license filter rejects misleading CC0 prefixes")
	misleading.license = "CC-BY-not-a-license"
	check(filters.apply([misleading], {"license": "attribution"}).is_empty(), "attribution filter rejects invented license prefixes")
	misleading.redistribution = "false"
	check(filters.apply([misleading], {"shareable": "yes"}).is_empty(), "string false cannot grant sharing filter eligibility")
	misleading.license = "CC-BY-SA-4.0"
	check(filters.apply([misleading], {"license": "attribution"}).size() == 1, "recognized versioned attribution license remains searchable")
	var large_catalog: Array = []
	for i in 1000:
		var record = records[i % 2].duplicate(true)
		record.id = str(i)
		large_catalog.append(record)
	var started = Time.get_ticks_usec()
	var selected: Array = filters.apply(large_catalog, {"type": "avatar", "license": "CC0", "query": "alex"})
	check(selected.size() == 500, "optimized filtering preserves combined results over 1000 entries")
	selected[0].title = "Changed copy"
	check(large_catalog[0].title == "Friendly Robot", "filter optimization preserves catalog immutability")
	print("INFO: 1000-record combined filter elapsed microseconds: ", Time.get_ticks_usec() - started)

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
	for i in 64: cache.store(str(i), texture)
	cache.store("32", texture)
	check(cache.entries.size() == 64 and cache.entries.has("0"), "updating existing full-cache entry does not evict unrelated texture")
	cache.get_texture("0")
	cache.store("new", texture)
	check(cache.entries.has("0") and not cache.entries.has("1"), "thumbnail eviction preserves recently viewed textures rather than insertion order")

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
	var padded: Dictionary = oauth.accept_callback(config.redirect_uri + "?code=abc=def==&state=" + oauth.state, config)
	check(padded.get("code") == "abc=def==", "OAuth code containing equals is not truncated")
	oauth.begin(config)
	var form_encoded: Dictionary = oauth.accept_callback(config.redirect_uri + "?code=hello+world&state=" + oauth.state, config)
	check(form_encoded.get("code") == "hello world", "OAuth callback decodes form plus as space")
	oauth.begin(config)
	var replaced = config.duplicate()
	replaced.client_id = "different-client"
	check(oauth.accept_callback(config.redirect_uri + "?code=fixture&state=" + oauth.state, replaced).is_empty(), "OAuth callback cannot switch client configuration mid-session")
	for redirect in ["http://127.0.0.1:bad/callback", "http://127.0.0.1:70000/callback"]:
		var invalid = config.duplicate()
		invalid.redirect_uri = redirect
		check(oauth.begin(invalid).is_empty(), "OAuth rejects invalid loopback callback port")
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
	for invalid in ["https://example.test\t/path", "https://example.test:abc/catalog", "https://example.test:70000/catalog", "https://:443/catalog"]:
		check(not policy.valid_url(invalid), "malformed/control-character API endpoint rejected")
	check(policy.valid_url("https://example.test:8443/catalog") and policy.valid_url("https://[::1]:443/catalog"), "valid explicit ports and bracketed IPv6 remain supported")
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

func test_content_negotiation():
	var service = component("discovery_service", ["configure", "request_bytes", "search"])
	if service == null: return
	var base = "http://127.0.0.1:" + FileAccess.get_file_as_string("res://port.txt")
	service.configure({"id": "negotiation", "base_url": base + "/catalog", "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	var reader = load("res://scripts/assets/humanoid_animation.gd").new()
	for endpoint in ["/negotiated-avatar", "/redirect-avatar"]:
		var response: Dictionary = await service.request_bytes(base + endpoint)
		check(response.has("bytes") and not reader.document(response.get("bytes", PackedByteArray())).is_empty(),
			"byte download negotiates raw GLB, not JSON envelope: " + endpoint)
	for endpoint in ["/catalog", "/redirect-relative"]:
		service.configure({"id": "negotiation", "base_url": base + endpoint, "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
		var result: Dictionary = await service.search({})
		check(not result.has("error") and result.get("request_received", {}).get("accept") == "application/json",
			"catalog explicitly negotiates JSON including redirects: " + endpoint)
	var policy = load(BASE + "request_policy.gd").new()
	var prepared: Dictionary = policy.prepare_request({"kind": "builtin"}, "https://example.test/avatar.vrm", {})
	check("Accept: */*" in prepared.get("headers", []), "generic byte request policy defaults to Accept */*")
	check(policy.prepare_request({"kind": "builtin"}, "https://example.test/avatar.vrm", {}, false, "*/*\r\nAuthorization: injected").is_empty(),
		"representation selection cannot inject request headers")
	dispose(service)

func test_loopback_search():
	var service = component("discovery_service", ["configure", "search"])
	if service == null: return
	var base = "http://127.0.0.1:" + FileAccess.get_file_as_string("res://port.txt")
	service.configure({"id": "fixture", "base_url": base, "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	for endpoint in ["/redirect-relative", "/redirect-query", "/redirect-origin"]:
		var redirected: Dictionary = await service.request_bytes(base + endpoint)
		check(redirected.has("bytes"), "valid relative redirect resolves safely: " + endpoint)
	var private_redirect: Dictionary = await service.request_bytes(base + "/redirect-private")
	var truncated: Dictionary = await service.request_bytes(base + "/truncated", 2048)
	check(truncated.has("error") and not "size limit" in str(truncated.error).to_lower(), "truncated small download is not misreported as exceeding avatar limit")
	var oversized: Dictionary = await service.request_bytes(base + "/oversize", 1024)
	check(oversized.has("error") and "limit" in str(oversized.error).to_lower() and "1024" in str(oversized.error), "actual oversized transfer reports exact configured byte budget")
	check(private_redirect.has("bytes") and private_redirect.get("no_store", false), "no-store survives redirect chain and prevents persistent import")
	# Test-only transport override; normal configuration must still require HTTPS.
	service.configure({"id": "fixture", "base_url": base, "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	var result: Dictionary = await service.search({"query": "", "type": "all", "cursor": ""})
	check(result.get("items", []).size() == 2, "real loopback response lists avatars and animations")
	check(result.get("next_cursor") == "page-2", "provider pagination cursor retained")
	var received: Dictionary = result.get("request_received", {})
	check(received.has("authorization") and received.authorization == "" and received.get("cookie") == "", "server observes anonymous request without auth or cookies")
	result = await service.search({"query": "wave", "type": "animation", "cursor": ""})
	check(result.get("items", []).size() == 1 and result.items[0].type == "animation", "type filter reaches real HTTP provider")
	service.configure({"id": "fixture", "base_url": base + "/null-cursor", "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	result = await service.search({"query": "", "type": "all"})
	check(result.get("next_cursor") == "", "null provider cursor means end of pagination rather than string null")
	service.configure({"id": "fixture", "base_url": base + "?existing=1", "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	result = await service.search({"query": "", "type": "all"})
	check(not result.has("error") and result.get("request_received", {}).get("query", {}).get("existing") == ["1"], "root endpoint with query keeps existing parameter intact")
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
	service.configure({"id": "fixture", "base_url": base + "/bad-consent", "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	result = await service.search({"query": "", "type": "all"})
	check(result.get("items", []).size() == 2 and not result.items[0].redistribution, "malformed numeric provider consent fails closed without runtime errors")
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
	check(not gate.evaluate({"type": "texture", "format": "glb"}).can_import, "unknown asset types cannot be imported as animations")
	check(not gate.evaluate({"type": "animation", "format": "vrma", "compatibility": "verified", "redistribution": 1, "license": "CC0"}).can_equip, "numeric truth does not grant asset redistribution consent")
	var record = {"type": "avatar", "format": "vrm", "compatibility": "unknown", "license": "CC0-1.0", "redistribution": true}
	check(not gate.evaluate(record).get("can_equip", true), "public metadata cannot bypass importer validation")
	record.compatibility = "verified"
	record.redistribution = false
	check(not gate.evaluate(record).get("can_equip", true), "downloadable model without redistribution cannot equip")
	record.format = "fbx"
	check(not gate.evaluate(record).get("can_import", true), "unsupported FBX is not silently accepted")
	dispose(gate)

func test_audit_regressions():
	var service = load(BASE + "discovery_service.gd").new()
	root.add_child(service)
	var base = "http://127.0.0.1:" + FileAccess.get_file_as_string("res://port.txt")
	service.configure({"id": "audit", "adapter": "osa", "base_url": base + "/osa-malformed", "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	var result: Dictionary = await service.search({})
	check(result.get("items", []).all(func(item): return item.id != "private"), "AUDIT string false cannot publish private OSA avatar")
	check(result.get("items", []).all(func(item): return item.get("download_url") is String and item.get("thumbnail_url") is String), "AUDIT malformed OSA URL fields cannot escape normalization")
	service.configure({"id": "audit", "adapter": "osa", "base_url": base + "/bad", "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	result = await service.search({})
	check(result.has("error"), "AUDIT changed endpoint cannot reuse old catalog by source ID")
	service.configure({"id": "vox-audit", "adapter": "vox", "base_url": base + "/vox-malformed", "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	result = await service.search({})
	check(result.get("items", []).size() == 1, "AUDIT malformed motion manifest entries are skipped without aborting catalog")
	check(result.get("items", []).all(func(item): return item.get("sha256") is String and item.get("page_url") is String), "AUDIT motion digest and page metadata normalized to strings")
	service.configure({"id": "no-store", "adapter": "osa", "base_url": base + "/osa-no-store", "kind": "builtin", "auth": "none"}, {"allow_loopback_http": true})
	result = await service.search({})
	check(result.get("items", []).size() == 1 and not service.catalogs.has("no-store"), "AUDIT no-store catalog can be displayed without retaining cached metadata")
	service.queue_free()
	var browser = load("res://scenes/GUI/avatar_browser.tscn").instantiate()
	root.add_child(browser)
	browser.registry.add_source({"id": "audit-private", "kind": "custom", "auth": "bearer", "base_url": "https://private.example.test"})
	var page = browser.sources_page
	page.credential_store.queue_free()
	page.credential_store = DelayedKeyring.new()
	page.add_child(page.credential_store)
	page.restore_credential("audit-private")
	page.forget_credential("audit-private")
	await process_frame
	await process_frame
	check(browser.registry.get_credentials("audit-private").is_empty(), "AUDIT sign-out invalidates pending keyring credential restoration")
	browser.detail.visible = true
	browser._home()
	check(not browser.detail.visible, "AUDIT Home navigation hides stale asset detail and its Apply action")
	browser.compact = false
	browser.detail.visible = true
	browser._restore_results()
	check(not browser.detail.visible, "AUDIT Back closes detail in wide layout as well as compact")
	browser.free()

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
	for id in ["osa-r2", "osa-r3", "osa-neon"]:
		check(browser.registry.sources.has(id), "additional avatar catalog is enabled by default: " + id)
	check(browser.registry.sources.values().all(func(item): return item.auth == "none"), "all built-in adapters are anonymous")
	check(browser.services.is_empty(), "opening browser does not start unconsented network requests")
	browser.saved_records = [{"provider": "osa", "id": "restore", "title": "Restored", "type": "avatar"}]
	browser.return_record = "osa:restore"
	browser._restore_results()
	check(browser.card_buttons.has("osa:restore"), "Back restores existing result cards without another catalog request")
	check(browser.services.is_empty(), "restoring results never refetches catalog metadata")
	check(browser.has_method("_update_pagination"), "pagination owns exactly one reusable Load more control")
	if browser.has_method("_update_pagination"):
		browser.cursors = {"osa": "24"}
		browser._update_pagination()
		browser._update_pagination()
		var buttons = browser.results.get_children().filter(func(node): return node is Button and node.text == "Load more")
		check(buttons.size() == 1, "repeated pages do not accumulate Load more buttons")
		browser.cursors.clear()
		browser._update_pagination()
		check(browser.results.get_children().filter(func(node): return node is Button and node.text == "Load more").is_empty(), "final page removes obsolete Load more action")
	check(browser.has_method("_remember_feed_record"), "category feed cards preserve their own Back results")
	if browser.has_method("_remember_feed_record"):
		browser.saved_records.clear()
		browser._remember_feed_record({"provider": "osa", "id": "feed", "title": "Feed avatar", "type": "avatar"})
		browser._restore_results()
		check(browser.card_buttons.has("osa:feed") and not browser.card_buttons.has("osa:restore"), "Back from feed detail never restores unrelated previous search")
	if not browser.has_method("submit_home_search") or not browser.has_method("select_category") or not browser.has_method("get_search_state"):
		check(false, "browser exposes Home search/category acceptance API")
		skipped += 1
		browser.free()
		return
	browser.submit_home_search("robot dance")
	var state: Dictionary = browser.get_search_state()
	check(state.get("tab") == "search" and state.get("query") == "robot dance", "Home submit switches to Search with exact query")
	check(state.get("cursor", "") == "", "new Home search resets pagination")
	browser.state.tag = "unrelated-tag"
	browser.tag_field.text = "unrelated-tag"
	browser.state.loop = "yes"
	browser.state.compatibility = "verified"
	browser.select_category("robots")
	state = browser.get_search_state()
	check(state.get("tab") == "search" and state.get("category") == "robots", "Home category opens filtered Search")
	check(state.get("tag", "") == "" and state.get("loop", "all") == "all" and state.get("compatibility", "all") == "all", "category navigation clears incompatible stale filters")
	check(browser.tag_field.text.is_empty() and browser.filter_controls.loop.selected == 0, "category filter reset is visible in controls as well as query state")
	browser.free()

func test_live_sources():
	var service = load(BASE + "discovery_service.gd").new()
	root.add_child(service)
	for source in [
		{"id": "osa", "kind": "builtin", "auth": "none", "adapter": "osa", "base_url": service.OSA + "avatars/100avatars-r1.json"},
		{"id": "osa-r2", "kind": "builtin", "auth": "none", "adapter": "osa", "base_url": service.OSA + "avatars/100avatars-r2.json"},
		{"id": "osa-r3", "kind": "builtin", "auth": "none", "adapter": "osa", "base_url": service.OSA + "avatars/100avatars-r3.json"},
		{"id": "osa-neon", "kind": "builtin", "auth": "none", "adapter": "osa-neon", "base_url": service.OSA + "avatars/NeonGlitch86.json"},
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

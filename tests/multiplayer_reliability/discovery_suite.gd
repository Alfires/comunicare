extends SceneTree
var passed := 0
var failed := 0
const WORLD = "https://example.invalid/world.cne"

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func browser():
	var scene = load("res://scenes/GUI/world_explorer.tscn").instantiate()
	scene.set_script(load("res://fixtures/browser.gd"))
	root.add_child(scene)
	return scene

func run():
	test_catalog_bounds()
	test_summary_shape()
	test_retry_liveness()
	test_query_intent()
	test_decoder_contract()
	print("\nRED discovery reliability: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

func test_catalog_bounds():
	var scene = browser()
	check(scene.http_request.body_size_limit > 0 and scene.http_request.body_size_limit <= 2 * 1024 * 1024, "catalog HTTP has an explicit bounded download size")
	scene._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify([
		{"url": WORLD, "name": "Trusted previous metadata", "description": "Last known good"}]).to_utf8_buffer())
	check(scene.worlds_list.size() == 1, "baseline valid catalog remains independent of live directory")
	var previous: Array = scene.worlds_list.duplicate(true)
	var malicious = [{"url": WORLD, "name": "x".repeat(1024 * 1024), "description": "y".repeat(1024 * 1024)}]
	scene._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(malicious).to_utf8_buffer())
	check(scene.worlds_list == previous, "oversized catalog metadata cannot replace last valid catalog")
	scene.load_sessions([{"mode": 0, "session_id": "visible", "world_url": WORLD, "player_count": 1}])
	check(scene.instances.has("visible"), "catalog state never prevents valid live public summary")
	scene.free()

func test_summary_shape():
	var scene = browser()
	scene.load_sessions([{"mode": 0, "session_id": "fractional", "world_url": WORLD, "player_count": 1.5},
		{"mode": 0, "session_id": "bad-name", "world_url": WORLD, "player_count": 1, "name": {"not": "text"}},
		{"mode": 0, "session_id": "valid", "world_url": WORLD, "player_count": 2, "name": "Room"},
		{"mode": 1, "session_id": "private", "world_url": WORLD, "player_count": 1}])
	check(not scene.instances.has("private"), "baseline discovery rejects private summaries")
	check(not scene.instances.has("fractional"), "public directory rejects fractional participant counts rather than truncating")
	check(not scene.instances.has("bad-name"), "directory rejects nontext names rather than stringifying arbitrary JSON")
	check(scene.instances.has("valid"), "strict validation still retains valid public entries")
	scene.free()

func test_retry_liveness():
	var handler = root.get_node("NetworkHandler")
	var peer = RelayPeer.new()
	peer.is_connected_to_relay = true
	peer.is_authenticated = true
	handler.peer = peer
	var scene = browser()
	check(scene.refreshing, "baseline connected browser starts one discovery request")
	scene.refresh_started = Time.get_ticks_msec() - 10001
	scene._process(0)
	# Legacy no-correlation path must at least release its failed request; a
	# future correlated client may instead expose a fresh retry generation.
	var request_id = scene.get("discovery_request_id")
	check(not scene.refreshing or (request_id != null and not str(request_id).is_empty()), "silent relay cannot keep browser permanently latched without retry identity")
	check(scene.has_method("receive_directory_result"), "discovery exposes correlation-aware response acceptance")
	if scene.has_method("receive_directory_result"):
		var before = scene.instances.duplicate(true)
		scene.receive_directory_result({"request_id": "obsolete", "generation": "obsolete", "sessions": [{"session_id": "stale", "world_url": WORLD, "mode": 0, "player_count": 1}]})
		check(scene.instances == before, "obsolete directory response cannot finish or replace current snapshot")
	scene.free()
	handler.peer = null

func test_query_intent():
	var scene = browser()
	check(scene.has_method("classify_query"), "world filter text is distinguishable from explicit URL and session code")
	if scene.has_method("classify_query"):
		check(scene.classify_query("Friendly hangout") == "filter", "ordinary multiword search stays a local filter")
		check(scene.classify_query(WORLD) == "url", "world URL is an explicit content action")
		check(scene.classify_query("Ab12C") == "code", "bounded room-code syntax is an explicit instance action")
	scene.free()

func test_decoder_contract():
	# Existing direct JSON parsers can emit engine errors on hostile input. Do
	# not call them as though ERROR output were an acceptable red assertion.
	var path = "res://relay_protocol/decode_result.gd"
	check(ResourceLoader.exists(path), "network ingress has bounded quiet decode result contract")
	if not ResourceLoader.exists(path): return
	var decoder = load(path).new()
	check(decoder.has_method("json_object"), "quiet decoder supplies json_object(bytes, max_bytes)")
	if decoder.has_method("json_object"):
		check(not decoder.json_object("{broken".to_utf8_buffer(), 1024).get("ok", true), "malformed JSON fails quietly")
		check(not decoder.json_object("[]".to_utf8_buffer(), 1024).get("ok", true), "wrong top-level JSON type is rejected")
		check(not decoder.json_object("{\"x\":1}".to_utf8_buffer(), 2).get("ok", true), "byte limit applies before JSON parse")
		check(decoder.json_object("{\"request_id\":\"one\"}".to_utf8_buffer(), 1024).get("ok", false), "valid bounded object remains decodable")
	if decoder is Node: decoder.free()

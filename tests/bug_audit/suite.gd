extends SceneTree
var passed := 0
var failed := 0
const Reader = preload("res://scripts/assets/humanoid_animation.gd")
const Registry = preload("res://scripts/discovery/avatars/source_registry.gd")
const Policy = preload("res://scripts/discovery/avatars/request_policy.gd")

func _initialize(): call_deferred("run")
func check(ok: bool, id: int, title: String):
	if ok: passed += 1
	else: failed += 1
	print("PASS " if ok else "FAIL ", "%02d: " % id, title)

func source(id: String = "custom") -> Dictionary:
	return {"id": id, "kind": "custom", "auth": "bearer", "base_url": "https://example.test/catalog"}

func pack(json: Dictionary, binary: PackedByteArray, include_binary: bool = true) -> PackedByteArray:
	var text = JSON.stringify(json).to_utf8_buffer()
	while text.size() % 4: text.append(32)
	var bytes = PackedByteArray(); bytes.resize(20)
	bytes.encode_u32(0, 0x46546c67); bytes.encode_u32(4, 2)
	bytes.encode_u32(12, text.size()); bytes.encode_u32(16, 0x4e4f534a)
	bytes.append_array(text)
	if include_binary:
		var header = PackedByteArray(); header.resize(8)
		header.encode_u32(0, binary.size()); header.encode_u32(4, 0x004e4942)
		bytes.append_array(header); bytes.append_array(binary)
	bytes.encode_u32(8, bytes.size())
	return bytes

func fixture() -> Dictionary:
	return {"asset": {"version": "2.0"}, "nodes": [{"name": "Hips"}],
		"extensions": {"VRMC_vrm_animation": {"humanoid": {"humanBones": {"hips": {"node": 0}}}}},
		"buffers": [{"byteLength": 40}], "bufferViews": [{"buffer": 0, "byteLength": 8}, {"buffer": 0, "byteOffset": 8, "byteLength": 32}],
		"accessors": [{"bufferView": 0, "componentType": 5126, "count": 2, "type": "SCALAR"}, {"bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC4"}],
		"animations": [{"samplers": [{"input": 0, "output": 1}], "channels": [{"sampler": 0, "target": {"node": 0, "path": "rotation"}}]}]}

func run():
	var registry = Registry.new()
	for i in 64: registry.add_source(source(str(i)))
	check(not registry.add_source(source("overflow")), 1, "custom API count cannot grow without bound")
	registry = Registry.new()
	check(not registry.add_source({"id": "bad", "kind": "builtin", "base_url": "https://example.test", "adapter": "typo"}), 2, "unknown built-in adapter rejected instead of returning empty success")
	check(not registry.add_source(source("  ")), 3, "blank source identity rejected")
	registry.add_source(source())
	check(not registry.set_credentials("custom", {"token": "bad\tcredential"}), 4, "control characters cannot enter authentication headers")
	var config = {"authorization_url": "https://example.test/authorize", "token_url": "https://example.test/token", "client_id": "x".repeat(257), "redirect_uri": "http://127.0.0.1:12345/callback"}
	check(not registry.add_source({"id": "oauth", "kind": "custom", "base_url": "https://example.test", "auth": "oauth", "oauth": config}), 5, "OAuth client ID is not silently truncated into wrong identity")
	var policy = Policy.new()
	check(not policy.valid_url("https://-bad..example/catalog"), 6, "invalid DNS labels rejected before HTTPRequest")
	check(not policy.valid_url("https://example.test:+443/catalog"), 7, "signed port syntax rejected")
	check(policy.prepare_request(source(), "https://example.test/catalog", {"token": 123}).is_empty(), 8, "numeric credentials never become bearer strings")
	check(not policy.prepare_request(source(), "https://example.test:443/catalog", {"token": "valid"}).is_empty(), 9, "equivalent default HTTPS port retains same-origin credentials")
	var oauth = load("res://scripts/discovery/avatars/oauth_session.gd").new()
	config.client_id = "public"
	var invalid = config.duplicate(); invalid.redirect_uri = "http://127.0.0.1:12345"
	check(oauth.begin(invalid).is_empty(), 10, "OAuth loopback must have callback path")
	invalid = config.duplicate(); invalid.authorization_url += "?state=old"
	check(oauth.begin(invalid).is_empty(), 11, "OAuth reserved parameters cannot be duplicated by configured endpoint")
	oauth.begin(config)
	check(oauth.accept_callback(config.redirect_uri + "?code=+++&state=" + oauth.state, config).is_empty(), 12, "blank OAuth code rejected after form decoding")
	var dial = load("res://scripts/GUI/circular_value_control.gd").new()
	dial.configure("invalid", NAN, 0, 1, 0.1, "", Callable())
	check(is_finite(dial.value), 13, "nonfinite initial dial value cannot poison draw coordinates")
	var calls: Array = []
	dial.configure("precision", 100000, 100000, 100010, 0.1, "", func(v): calls.append(v))
	dial.set_fraction(0.01)
	check(calls.size() == 1 and is_equal_approx(dial.value, 100000.1), 14, "small legitimate step not suppressed by relative epsilon at large baseline")
	var provider = load("res://scripts/assets/tracker_role_provider.gd").new()
	provider.update_sample("negative", Transform3D.IDENTITY, true, -1)
	check(not provider.samples.has("negative"), 15, "negative tracker clock sample rejected")
	provider.update_sample("singular", Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO), true, 1)
	check(not provider.available(1).has("singular"), 16, "singular tracker basis cannot be offered for calibration")
	for i in 300: provider.update_sample("device-" + str(i), Transform3D.IDENTITY, true, i)
	check(provider.samples.size() <= 256, 17, "ephemeral tracker inventory bounded under device churn")
	var calibration = load("res://scripts/assets/tracking_calibration.gd").new()
	var singular = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	check(calibration.capture_roles({"hips": singular}, {"hips": Transform3D.IDENTITY}).is_empty(), 18, "singular calibration sample rejected before matrix inverse")
	check(calibration.capture_roles({"not-a-role": Transform3D.IDENTITY}, {"not-a-role": Transform3D.IDENTITY}).is_empty(), 19, "unsupported calibration role cannot be captured")
	check(calibration.calibrated_targets({"hips": singular}, {"hips": [0, 0, 0, 0, 0, 0, 1]}).is_empty(), 20, "invalid calibration target does not reach skeleton solver")
	var layout = load("res://scripts/assets/emote_layout.gd").new()
	check(not layout.add_emote("root", "new", "   "), 21, "invisible blank emote label rejected")
	var candidate = layout.groups.duplicate(true)
	candidate.root.entries.append(candidate.root.entries[0].duplicate())
	check(not layout.commit(candidate), 22, "persisted duplicate shortcut cannot bypass add API validation")
	var reader = Reader.new()
	var binary = PackedFloat32Array([0, 1, 0, 0, 0, 1, 0, 0.3826834, 0, 0.9238795]).to_byte_array()
	var doc = fixture(); doc.asset.minVersion = "2.1"
	check(reader.document(pack(doc, binary)).is_empty(), 23, "unsupported glTF minimum version rejected")
	var empty_first = pack({}, PackedByteArray(), false)
	var valid = pack(fixture(), binary)
	empty_first.append_array(valid.slice(12)); empty_first.encode_u32(8, empty_first.size())
	check(reader.document(empty_first).is_empty(), 24, "empty first JSON chunk cannot hide duplicate JSON chunk")
	doc = fixture(); doc.erase("buffers")
	check(reader.document(pack(doc, binary)).is_empty(), 25, "undeclared BIN payload rejected")
	doc = fixture(); doc.images = [{"mimeType": "image/png"}]
	check(reader.document(pack(doc, binary)).is_empty(), 26, "embedded image requires valid bufferView rather than empty image entry")
	doc = fixture(); doc.extensions.VRMC_vrm_animation.humanoid.humanBones.head = {"node": 999}
	check(reader.read_bytes(pack(doc, binary)).is_empty(), 27, "invalid declared humanoid node cannot silently disappear from mapping")
	check(reader._quaternion([1.0e308, 0, 0, 1]) == Quaternion(0, 0, 0, 0), 28, "overflow quaternion cannot normalize to invalid rotation")
	doc = fixture(); doc.bufferViews[0].erase("buffer")
	check(reader.read_bytes(pack(doc, binary)).is_empty(), 29, "missing bufferView buffer reference rejected")
	check(reader._quaternion([0, 0, 0, 2]) == Quaternion(0, 0, 0, 0), 30, "nonunit rotation quaternion cannot silently distort import semantics")
	print("Audit: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

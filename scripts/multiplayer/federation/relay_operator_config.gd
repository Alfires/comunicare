extends RefCounted
## Explicit infrastructure configuration. Never stores users or session state.
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
var last_error := ""

func load_config(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 128 * 1024: return _fail("Relay infrastructure config unavailable/oversized")
	var parser = JSON.new()
	var status = parser.parse(file.get_as_text())
	file.close()
	if status != OK or not parser.data is Dictionary: return _fail("Invalid infrastructure JSON")
	var value: Dictionary = parser.data
	if not Guard.keys(value, ["schema", "key", "certificate", "bind", "port", "peers", "blocks", "lan_enabled", "label"]) or value.get("schema") != 1 \
		or not value.get("key") is String or not value.get("certificate") is String \
		or not Guard.integer(value.get("port"), 1, 65535) or not value.get("peers", []) is Array or value.get("peers", []).size() > 64 \
		or not value.get("blocks", []) is Array or value.get("blocks", []).size() > 256: return _fail("Invalid infrastructure schema")
	var key = CryptoKey.new()
	var certificate = X509Certificate.new()
	if not FileAccess.file_exists(value.key) or not FileAccess.file_exists(value.certificate) or key.load(value.key) != OK or key.is_public_only() or certificate.load(value.certificate) != OK:
		return _fail("Cannot read relay infrastructure key/certificate; originals not replaced")
	for id in value.get("blocks", []):
		if not Guard.identity(id): return _fail("Invalid blocked relay ID")
	var peers: Array = []
	for peer in value.get("peers", []):
		if not peer is Dictionary or not Guard.keys(peer, ["host", "port", "public_key", "certificate", "common_name", "connect"]) \
			or not Guard.host(peer.get("host")) or not Guard.integer(peer.get("port"), 1, 65535) \
			or not peer.get("public_key") is String or not peer.get("certificate") is String: return _fail("Invalid relay peer configuration")
		var trusted_key = CryptoKey.new()
		var trusted_cert = X509Certificate.new()
		if not FileAccess.file_exists(peer.public_key) or not FileAccess.file_exists(peer.certificate) or trusted_key.load(peer.public_key, true) != OK or trusted_cert.load(peer.certificate) != OK:
			return _fail("Cannot load trusted relay key/certificate")
		peers.append({"host": peer.host, "port": int(peer.port), "key": trusted_key.save_to_string(true), "certificate": trusted_cert,
			"common_name": str(peer.get("common_name", "comunicare-relay")), "connect": peer.get("connect", true) == true})
	return {"ok": true, "key": key, "certificate": certificate, "bind": str(value.get("bind", "0.0.0.0")), "port": int(value.port),
		"peers": peers, "blocks": value.get("blocks", []).duplicate(), "lan_enabled": value.get("lan_enabled", false) == true, "label": str(value.get("label", "Comunicare relay")).left(128)}

func _fail(message: String) -> Dictionary:
	last_error = message
	return Guard.failure(message)

extends RefCounted
## Explicit local trust bundle. No automatic certificate acceptance from advertisements.
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
var path := "user://relay_directory_trust.json"
var entries: Array = []
var last_error := ""
var write_blocked := false

func load_trust() -> bool:
	if not FileAccess.file_exists(path): return true
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 512 * 1024: return _fail("Trust bundle unreadable/oversized", true)
	var parser = JSON.new()
	var result = parser.parse(file.get_as_text())
	file.close()
	if result != OK or not parser.data is Dictionary or parser.data.get("schema") != 1 or not parser.data.get("entries") is Array or parser.data.entries.size() > 64:
		return _fail("Trust bundle corrupt/unsupported; original preserved", true)
	var verified: Array = []
	for entry in parser.data.entries:
		if not _valid(entry): return _fail("Invalid trust entry; original preserved", true)
		verified.append(entry.duplicate(true))
	entries = verified
	return true

func _valid(entry: Variant) -> bool:
	return entry is Dictionary and Guard.keys(entry, ["relay_id", "host", "port", "common_name", "certificate"]) \
		and Guard.identity(entry.get("relay_id")) and Guard.host(entry.get("host")) and Guard.integer(entry.get("port"), 1, 65535) \
		and Guard.text(entry.get("common_name"), 253) and entry.get("certificate") is String and entry.certificate.length() <= 16384 \
		and entry.certificate.begins_with("-----BEGIN CERTIFICATE-----")

func add_certificate(id: String, host: String, port: int, certificate_path: String, common_name: String = "comunicare-relay") -> bool:
	if write_blocked or entries.size() >= 64: return _fail("Trust bundle read-only or full")
	var file = FileAccess.open(certificate_path, FileAccess.READ)
	if file == null or file.get_length() > 16384: return _fail("Certificate file unavailable/oversized")
	var pem = file.get_as_text()
	file.close()
	var entry = {"relay_id": id, "host": host, "port": port, "common_name": common_name, "certificate": pem}
	if not _valid(entry): return _fail("Invalid certificate entry")
	var cert = X509Certificate.new()
	if cert.load_from_string(pem) != OK: return _fail("Invalid X509 certificate")
	for old in entries:
		if old.relay_id == id: return _fail("Relay already trusted; remove it before explicitly approving a key change")
	entries.append(entry)
	if not _save():
		entries.pop_back()
		return false
	return true

func remove(id: String) -> bool:
	if write_blocked: return false
	var old = entries.duplicate(true)
	for index in range(entries.size() - 1, -1, -1):
		if entries[index].relay_id == id: entries.remove_at(index)
	if not _save():
		entries = old
		return false
	return true

func apply_to(client):
	for entry in entries:
		var cert = X509Certificate.new()
		if cert.load_from_string(entry.certificate) == OK: client.add_trusted(entry.host, int(entry.port), entry.relay_id, cert, entry.common_name)

func _save() -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return _fail("Cannot write relay trust bundle")
	file.store_string(JSON.stringify({"schema": 1, "entries": entries}, "  "))
	file.close()
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: return _fail("Cannot replace relay trust bundle")
	return true

func _fail(message: String, preserve: bool = false) -> bool:
	last_error = message
	write_blocked = write_blocked or preserve
	return false

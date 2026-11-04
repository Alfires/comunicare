extends RefCounted
## Application-shipped discovery seeds, never the user's ingress/fallback order.
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
var last_error := ""

func load_presets(path: String = "res://config/relay_presets.json") -> Array:
	last_error = ""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 512 * 1024:
		last_error = "Relay preset file unavailable or oversized"
		return []
	var parser = JSON.new()
	var status = parser.parse(file.get_as_text())
	file.close()
	if status != OK or not parser.data is Dictionary or not Guard.keys(parser.data, ["schema", "relays"]) or parser.data.get("schema") != 1 or not parser.data.get("relays") is Array or parser.data.relays.size() > 64:
		last_error = "Invalid relay preset schema"
		return []
	var result: Array = []
	var seen: Dictionary = {}
	for entry in parser.data.relays:
		if not entry is Dictionary or not Guard.keys(entry, ["relay_id", "label", "host", "port", "certificate", "common_name"]) \
			or not Guard.identity(entry.get("relay_id")) or seen.has(entry.relay_id) or not Guard.text(entry.get("label"), 128) \
			or not Guard.host(entry.get("host")) or not Guard.integer(entry.get("port"), 1, 65535) \
			or not Guard.text(entry.get("common_name"), 253) or not entry.get("certificate") is String or entry.certificate.length() > 16384 or not entry.certificate.begins_with("-----BEGIN CERTIFICATE-----"):
			last_error = "Invalid or duplicate relay preset"
			return []
		seen[entry.relay_id] = true
		result.append(entry.duplicate(true))
	return result

func apply_to(client, entries: Array):
	for entry in entries:
		# Explicit device trust takes precedence over application defaults.
		if client.trusted.has(entry.relay_id): continue
		var cert = X509Certificate.new()
		if cert.load_from_string(entry.certificate) == OK:
			client.add_trusted(entry.host, int(entry.port), entry.relay_id, cert, entry.common_name)

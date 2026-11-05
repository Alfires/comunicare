extends RefCounted
var sessions: Dictionary = {}
func prepare(document: Dictionary, mode: String, path: String) -> Dictionary:
	if mode not in ["desktop", "vr"]: return {"ok": false}
	var result = preload("res://addons/comunicare_world_tools/world_exporter.gd").new().export_package(document, path)
	if not result.ok: return result
	var token = Crypto.new().generate_random_bytes(16).hex_encode()
	sessions[token] = document.duplicate(true)
	return {"ok": true, "token": token, "temporary_progress": true, "launch_supported": false}
func restore(token: String) -> Dictionary:
	if not sessions.has(token): return {"ok": false}
	var source = sessions[token]
	sessions.erase(token)
	return {"ok": true, "document": source}

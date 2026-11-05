@tool
extends RefCounted
## Planning only: never launches against creator's account or pretends XR exists.
func plan(package: String, mode: String, count: int) -> Dictionary:
	if mode not in ["desktop", "vr"] or count < 1 or count > 4 or not FileAccess.file_exists(package): return {"ok": false, "error": "Invalid playtest mode/count/package"}
	var checked = preload("res://scripts/worlds/world_package_reader.gd").new().inspect_package(package)
	if not checked.ok: return checked
	var clients: Array = []
	var run = Crypto.new().generate_random_bytes(16).hex_encode()
	for i in count:
		clients.append({"user_data": "user://world-playtests/" + run + "/client-" + str(i), "temporary_identity": true, "microphone_muted": true, "mode": mode, "package": package})
	return {"ok": true, "clients": clients, "launch_supported": false, "notice": "Isolated production-player launch integration pending"}

extends RefCounted
## Shared built-in spawn and locally generated dependency revision, not remote code.
const SPAWN := Vector3(0, 1, 0)
const REVISION_PATH := "res://scenes/worlds/welcome_island/revision.json"

static func reset_player(player: Node3D, target: Vector3 = SPAWN):
	if not is_instance_valid(player) or not target.is_finite(): return
	if player.has_method("set_player_pos"):
		player.set_player_pos(target)
	else:
		player.global_position = target
	if player is CharacterBody3D: player.velocity = Vector3.ZERO
	# Never write a tracked camera/origin's local pose or force head rotation.

static func revision() -> String:
	if not FileAccess.file_exists(REVISION_PATH): return ""
	var document = JSON.parse_string(FileAccess.get_file_as_string(REVISION_PATH))
	if not document is Dictionary or not document.get("files") is Dictionary: return ""
	var names = document.files.keys()
	names.sort()
	var lines := PackedStringArray()
	for name in names:
		# Editor/source builds detect edits immediately. Exports use the verified
		# pre-export hashes for resources transformed/remapped by Godot's exporter.
		var hash: String = document.files[name]
		if OS.has_feature("editor"):
			if not FileAccess.file_exists("res://" + name): return ""
			hash = FileAccess.get_sha256("res://" + name)
		lines.append(name + ":" + hash)
	return ("\n".join(lines) + "\n").sha256_text()

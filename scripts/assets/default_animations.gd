extends RefCounted
## Quaternius Universal Animation Library Standard-1.0, CC0-1.0.
## Extracted authored data, not procedural motion. See asset manifest/license.

const VERSION = 2
const LIBRARY = "quaternius.directional.v3"
const IDS = ["walk", "run", "strafe_left", "strafe_right", "jump", "dance", "interact"]
static var library: Dictionary = {}

static func clip(id: String) -> Dictionary:
	if library.is_empty():
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://assets/animations/quaternius_standard.json")) != OK:
			return {}
		for role in parser.data.clips:
			var source: Dictionary = parser.data.clips[role]
			var result = {"name": role, "duration": source.duration, "tracks": [], "provenance": source.provenance, "source_clip": source.source_clip}
			for track in source.tracks:
				var q: Array = track.source_rest
				var keys: Array = []
				for key in track.keys:
					keys.append({"time": key[0], "rotation": Quaternion(key[1], key[2], key[3], key[4])})
				result.tracks.append({"bone": track.bone, "source_rest": Quaternion(q[0], q[1], q[2], q[3]),
					"reference_space": "gltf_humanoid",
					"keys": keys, "optional": track.bone not in ["hips", "spine", "head", "leftUpperArm", "rightUpperArm", "leftLowerArm", "rightLowerArm", "leftHand", "rightHand", "leftUpperLeg", "rightUpperLeg", "leftLowerLeg", "rightLowerLeg", "leftFoot", "rightFoot"]})
			library[role] = result
	return library.get(id, {})

extends RefCounted
## Original procedural motion recipes; dedicated to CC0-1.0.
## No third-party motion capture, models or animation data are embedded.

const VERSION = 1
const IDS = ["idle", "walk", "run", "jump", "fall", "land", "wave", "cheer"]

static func clip(id: String) -> Dictionary:
	var result = {"name": id, "duration": 1.0, "tracks": []}
	match id:
		"idle":
			result.duration = 3.0
			_add(result, "spine", Vector3.RIGHT, [0.0, 0.018, 0.0], 3.0)
		"walk", "run":
			var duration = 0.8 if id == "walk" else 0.5
			var swing = 0.35 if id == "walk" else 0.65
			result.duration = duration
			_add(result, "leftUpperLeg", Vector3.RIGHT, [-swing, swing, -swing], duration)
			_add(result, "rightUpperLeg", Vector3.RIGHT, [swing, -swing, swing], duration)
			_add(result, "leftUpperArm", Vector3.RIGHT, [swing, -swing, swing], duration)
			_add(result, "rightUpperArm", Vector3.RIGHT, [-swing, swing, -swing], duration)
		"jump":
			result.duration = 0.6
			_add(result, "leftUpperLeg", Vector3.RIGHT, [0.0, -0.5, -0.15], 0.6)
			_add(result, "rightUpperLeg", Vector3.RIGHT, [0.0, -0.5, -0.15], 0.6)
		"fall":
			_add(result, "leftUpperArm", Vector3.FORWARD, [0.0, 0.25, 0.0], 1.0)
			_add(result, "rightUpperArm", Vector3.FORWARD, [0.0, -0.25, 0.0], 1.0)
		"land":
			result.duration = 0.35
			_add(result, "leftLowerLeg", Vector3.RIGHT, [0.0, 0.4, 0.0], 0.35)
			_add(result, "rightLowerLeg", Vector3.RIGHT, [0.0, 0.4, 0.0], 0.35)
		"wave":
			result.duration = 2.0
			_add(result, "rightUpperArm", Vector3.FORWARD, [0.0, -1.4, -1.4, -1.4, 0.0], 2.0)
			_add(result, "rightLowerArm", Vector3.UP, [0.0, 0.8, -0.2, 0.8, 0.0], 2.0)
		"cheer":
			result.duration = 2.0
			_add(result, "leftUpperArm", Vector3.FORWARD, [0.0, 1.8, 1.8, 0.0], 2.0)
			_add(result, "rightUpperArm", Vector3.FORWARD, [0.0, -1.8, -1.8, 0.0], 2.0)
		_:
			return {}
	return result

static func _add(result: Dictionary, bone: String, axis: Vector3, angles: Array, duration: float):
	var keys: Array = []
	for i in angles.size():
		keys.append({"time": duration * i / (angles.size() - 1), "rotation": Quaternion(axis, angles[i])})
	result.tracks.append({"bone": bone, "keys": keys, "step": false})

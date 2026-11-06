class_name AnimationState
extends RefCounted

const VERSION = 2
const MAX_BYTES = 16 * 1024 * 1024
const MAX_AVATAR_BYTES = 1024 * 1024 * 1024

static func transfer_timeout_msec(size: int) -> int:
	# Keep bounded but permit the maximum model at a conservative 64 KiB/s.
	return maxi(900000, int(clampi(size, 0, MAX_AVATAR_BYTES) / 65536.0 * 1000) + 120000)
const CHUNK_BYTES = 8192
const BUILTINS = ["neutral", "walk", "run", "strafe_left", "strafe_right", "jump", "dance", "interact"]
const LIBRARY = "quaternius.directional.v4"
const DURATIONS = {"neutral": 1.0, "strafe_left": 1.3333333730697632, "strafe_right": 1.3333333730697632, "walk": 1.3333333730697632, "run": 0.9333333373069763, "jump": 1.3333333730697632, "fall": 2.5, "dance": 1.0, "interact": 2.0}

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value == int(value) and value >= minimum and value <= maximum

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

static func valid(value: Dictionary) -> bool:
	if not number(value.get("avatar_scale", 1.0), 0.25, 3.0): return false
	if value.get("version") != VERSION or not value.get("session_id") is String \
		or value.session_id.length() > 128 or value.session_id.is_empty() \
		or not integer(value.get("sequence"), 1, 2147483647) \
		or value.get("action") != "resolved" or value.get("kind") not in ["locomotion", "emote"] \
		or not value.get("role") is String or value.role.length() > 256 \
		or value.get("mask") not in ["full", "tracked_head_hands"] \
		or not integer(value.get("configuration_revision"), 0, 2147483647) \
		or not value.get("avatar_revision") is String or value.avatar_revision.length() > 64 \
		or not number(value.get("offset"), 0, 600) or not number(value.get("speed"), 0.25, 2.0) \
		or not value.get("loop") is bool or not number(value.get("duration"), 0.001, 600):
		return false
	if value.get("model_hash", "") != "" and (not InstanceState.valid_fingerprint(value.model_hash) \
		or not integer(value.get("model_size"), 20, MAX_AVATAR_BYTES)):
		return false
	if value.get("builtin") in BUILTINS:
		return value.get("library") == LIBRARY and value.get("hash", "") == ""
	return value.get("builtin", "") == "" and InstanceState.valid_fingerprint(value.get("hash")) \
		and integer(value.get("size"), 20, MAX_BYTES) and integer(value.get("clip"), 0, 63)

static func playhead(value: Dictionary, now_msec: float) -> float:
	var offset: float = value.get("offset", 0.0)
	if value.get("action") == "resolved":
		offset += maxf(0, now_msec - value.get("started", now_msec)) * 0.001 * value.get("speed", 1.0)
	return fposmod(offset, value.duration) if value.get("loop", false) else minf(offset, value.duration)

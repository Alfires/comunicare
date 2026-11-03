class_name AnimationState
extends RefCounted

const VERSION = 1
const MAX_BYTES = 16 * 1024 * 1024
const CHUNK_BYTES = 8192
const BUILTINS = ["idle", "walk", "run", "jump", "fall", "land", "wave", "cheer"]

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value == int(value) and value >= minimum and value <= maximum

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

static func valid(value: Dictionary) -> bool:
	if value.get("version") != VERSION or not value.get("session_id") is String \
		or value.session_id.length() > 128 or value.session_id.is_empty() \
		or not integer(value.get("sequence"), 1, 2147483647) \
		or value.get("action") not in ["play", "pause", "stop"] \
		or not number(value.get("offset"), 0, 600) or not number(value.get("speed"), 0.25, 2.0) \
		or not value.get("loop") is bool or not number(value.get("duration"), 0.001, 600):
		return false
	if value.get("builtin") in BUILTINS:
		return value.get("library") == "comunicare.procedural.v1" and value.get("hash", "") == ""
	return value.get("builtin", "") == "" and InstanceState.valid_fingerprint(value.get("hash")) \
		and integer(value.get("size"), 20, MAX_BYTES) and integer(value.get("clip"), 0, 63)

static func playhead(value: Dictionary, now_msec: float) -> float:
	var offset: float = value.get("offset", 0.0)
	if value.get("action") == "play":
		offset += maxf(0, now_msec - value.get("started", now_msec)) * 0.001 * value.get("speed", 1.0)
	return fposmod(offset, value.duration) if value.get("loop", false) else minf(offset, value.duration)

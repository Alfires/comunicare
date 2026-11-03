class_name FriendEvent
extends RefCounted

const Identity = preload("res://scripts/profile/profile_identity.gd")
const KINDS = ["request", "accept", "decline", "cancel", "revoke"]

static func bytes(value: Dictionary) -> PackedByteArray:
	return JSON.stringify(["comunicare/friendship/v1", value.get("event_id"), value.get("relationship_id"),
		value.get("kind"), value.get("actor"), value.get("recipient"), value.get("request_digest")]).to_utf8_buffer()

static func digest(value: Dictionary) -> String:
	return Identity.digest(bytes(value)).hex_encode()

static func create(key: CryptoKey, recipient: String, kind: String, request: Dictionary = {}) -> Dictionary:
	var id = Crypto.new().generate_random_bytes(32).hex_encode()
	var value = {"event_id": id, "relationship_id": id if kind == "request" else request.relationship_id,
		"kind": kind, "actor": key.save_to_string(true), "recipient": recipient,
		"request_digest": "" if kind == "request" else digest(request)}
	value.signature = Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, Identity.digest(bytes(value)), key))
	if kind != "request":
		value.request = request.duplicate(true)
	return value

static func valid(value: Dictionary, nested: bool = false) -> bool:
	for field in value:
		if field not in ["event_id", "relationship_id", "kind", "actor", "recipient", "request_digest", "signature", "request"]:
			return false
	if JSON.stringify(value).length() > 24000 or value.get("kind") not in KINDS \
		or not InstanceState.valid_fingerprint(value.get("event_id")) \
		or not InstanceState.valid_fingerprint(value.get("relationship_id")) \
		or not value.get("actor") is String or not value.get("recipient") is String \
		or not value.get("signature") is String or value.signature.length() > 2048:
		return false
	var actor = Identity.canonical_key(value.actor)
	var recipient = Identity.canonical_key(value.recipient)
	if actor.is_empty() or recipient.is_empty() or actor != value.actor or recipient != value.recipient or actor == recipient:
		return false
	var key = CryptoKey.new()
	key.load_from_string(actor, true)
	if not Crypto.new().verify(HashingContext.HASH_SHA256, Identity.digest(bytes(value)), Marshalls.base64_to_raw(value.signature), key):
		return false
	if value.kind == "request":
		return value.event_id == value.relationship_id and value.get("request_digest") == "" and not value.has("request")
	if nested or not value.get("request") is Dictionary or not valid(value.request, true) or value.request.kind != "request":
		return false
	var request: Dictionary = value.request
	if value.relationship_id != request.relationship_id or value.request_digest != digest(request):
		return false
	if value.kind in ["accept", "decline"]:
		return actor == request.recipient and recipient == request.actor
	if value.kind == "cancel":
		return actor == request.actor and recipient == request.recipient
	return [actor, recipient] == [request.actor, request.recipient] or [actor, recipient] == [request.recipient, request.actor]

static func valid_proof(proof: Dictionary) -> bool:
	return proof.get("request") is Dictionary and proof.get("accept") is Dictionary \
		and valid(proof.request) and valid(proof.accept) and proof.request.kind == "request" \
		and proof.accept.kind == "accept" and proof.accept.request == proof.request

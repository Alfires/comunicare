extends RefCounted

const Identity = preload("res://scripts/profile/profile_identity.gd")
var challenges: Dictionary = {}
var identities: Dictionary = {}
var last_rejection := ""
const CHALLENGE_LIFETIME_MS = 10000

func issue_challenge(connection_id: int, public_key: String) -> PackedByteArray:
	var canonical = Identity.canonical_key(public_key)
	if canonical.is_empty() or identities.has(connection_id):
		return PackedByteArray()
	var bytes = JSON.stringify(["comunicare/auth/v1", connection_id,
		Identity.fingerprint(canonical), Crypto.new().generate_random_bytes(32).hex_encode()]).to_utf8_buffer()
	challenges[connection_id] = {"bytes": bytes, "public_key": canonical,
		"expires": Time.get_ticks_msec() + CHALLENGE_LIFETIME_MS}
	return bytes

func verify_response(connection_id: int, signature: PackedByteArray) -> bool:
	last_rejection = "invalid_authentication"
	if not challenges.has(connection_id):
		return false
	var challenge: Dictionary = challenges[connection_id]
	challenges.erase(connection_id) # Single use, including failed attempts.
	if signature.size() > 1024:
		return false
	if Time.get_ticks_msec() >= challenge.expires:
		return false
	var key = CryptoKey.new()
	key.load_from_string(challenge.public_key, true)
	if not Crypto.new().verify(HashingContext.HASH_SHA256, Identity.digest(challenge.bytes), signature, key):
		return false
	var fingerprint = Identity.fingerprint(challenge.public_key)
	for identity in identities.values():
		if identity.fingerprint == fingerprint:
			last_rejection = "account_already_connected"
			return false # One live connection per account on this relay.
	identities[connection_id] = {"public_key": challenge.public_key, "fingerprint": fingerprint}
	last_rejection = ""
	return true

func get_identity(connection_id: int) -> Dictionary:
	return identities.get(connection_id, {}).duplicate(true)

func expire_challenges():
	challenges.clear()

func disconnect_peer(connection_id: int):
	challenges.erase(connection_id)
	identities.erase(connection_id)

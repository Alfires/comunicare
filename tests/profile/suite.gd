extends SceneTree

const SERVICE = "res://scripts/profile/profile_service.gd"
const IDENTITY = "res://scripts/profile/identity_authenticator.gd"
const PROFILE_SCENE = "res://scenes/GUI/profile_menue.tscn"
var passed := 0
var failed := 0
var deferred_groups: Array = []

func _initialize():
	call_deferred("run")

func check(ok: bool, title: String):
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func require_methods(object: Object, methods: Array, title: String) -> bool:
	var missing: Array = []
	for method in methods:
		if not object.has_method(method):
			missing.append(method)
	check(missing.is_empty(), title + ("; missing " + str(missing) if not missing.is_empty() else ""))
	return missing.is_empty()

func feature(path: String, title: String):
	var exists = ResourceLoader.exists(path)
	check(exists, title)
	return load(path).new() if exists else null

func dispose(object):
	if object is Node:
		object.free()

func key_pair() -> CryptoKey:
	# Ephemeral keys in memory only, never SaveData.create_acount()/key.save().
	return Crypto.new().generate_rsa(2048)

func digest(bytes: PackedByteArray) -> PackedByteArray:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()

func fields(name: String = "Alice") -> Dictionary:
	return {"profile.username": name, "profile.description": "Hello\nWorld",
		"profile.icon_source": "", "profile.avatar_url": "https://example.test/avatar.vrm"}

func test_profile_service():
	var service = feature(SERVICE, "dedicated key-owned profile service exists")
	if service == null:
		deferred_groups.append("profile ownership, atomic saves, validation and persistence")
		return
	if not require_methods(service, ["configure", "get_local_fingerprint", "get_profile", "can_edit", "save_profile", "load_profile"], "profile service contract"):
		deferred_groups.append("profile service behavior")
		dispose(service)
		return
	var alice = key_pair()
	var bob = key_pair()
	service.configure(alice, "res://alice-profile.cfg")
	var owner: String = service.get_local_fingerprint()
	check(not owner.is_empty() and service.can_edit(owner), "matching private key grants local profile ownership")
	check(service.get_profile(owner).get("profile.description") == ""
		and service.get_profile(owner).get("profile.icon_source") == "", "new identity gets empty description and bundled-icon selection")
	check(service.save_profile(owner, fields()), "owner can save all four profile fields")
	check(service.get_profile(owner).get("profile.description") == "Hello\nWorld", "multiline profile description is preserved")
	var snapshot: Dictionary = service.get_profile(owner).duplicate(true)
	var invalid = fields("Changed")
	invalid["profile.avatar_url"] = "file:///private/model.vrm"
	check(not service.save_profile(owner, invalid) and service.get_profile(owner) == snapshot,
		"one invalid field rejects whole profile without partial name change")
	for invalid_value in ["", "   ", "\n\t"]:
		invalid = fields(invalid_value)
		check(not service.save_profile(owner, invalid), "blank/control-only display name is rejected: " + str(invalid_value))
	invalid = fields()
	invalid["profile.description"] = "x".repeat(1025)
	check(not service.save_profile(owner, invalid), "description over 1024 characters rejected")
	var second = load(SERVICE).new()
	second.configure(bob, "res://bob-profile.cfg")
	var other: String = second.get_local_fingerprint()
	check(not second.can_edit(owner) and not second.save_profile(owner, fields("Impersonated")),
		"another private key cannot edit Alice even through direct service call")
	check(not service.can_edit(other) and not service.save_profile(other, fields()), "owner cannot write arbitrary other account records")
	var restarted = load(SERVICE).new()
	restarted.configure(alice, "res://alice-profile.cfg")
	check(restarted.load_profile() and restarted.get_local_fingerprint() == owner
		and restarted.get_profile(owner).get("profile.username") == "Alice", "same key restores profile after restart")
	var wrong_account = load(SERVICE).new()
	wrong_account.configure(bob, "res://alice-profile.cfg")
	wrong_account.load_profile()
	check(wrong_account.get_profile(other).get("profile.username") != "Alice", "loading another account's file never adopts its profile identity")
	for object in [service, second, restarted, wrong_account]:
		dispose(object)

func test_identity_authentication():
	var auth = feature(IDENTITY, "relay proof-of-key-possession authenticator exists")
	if auth == null:
		deferred_groups.append("challenge/signature/replay/connection-bound authentication")
		return
	if not require_methods(auth, ["issue_challenge", "verify_response", "get_identity", "expire_challenges", "disconnect_peer"], "authenticator API"):
		deferred_groups.append("authentication behavior")
		dispose(auth)
		return
	var alice = key_pair()
	var bob = key_pair()
	var public_key = alice.save_to_string(true)
	var challenge: PackedByteArray = auth.issue_challenge(1, public_key)
	var signature = Crypto.new().sign(HashingContext.HASH_SHA256, digest(challenge), alice)
	check(not challenge.is_empty() and auth.verify_response(1, signature), "valid private-key signature authenticates connection")
	check(auth.get_identity(1).get("public_key") == public_key, "verified connection resolves to canonical public key")
	check(not auth.verify_response(1, signature), "consumed challenge cannot be replayed")
	challenge = auth.issue_challenge(2, public_key)
	var forged = Crypto.new().sign(HashingContext.HASH_SHA256, digest(challenge), bob)
	check(not auth.verify_response(2, forged) and auth.get_identity(2).is_empty(), "claimed victim public key without private key does not authenticate")
	challenge = auth.issue_challenge(3, bob.save_to_string(true))
	signature = Crypto.new().sign(HashingContext.HASH_SHA256, digest(challenge), bob)
	check(not auth.verify_response(4, signature), "signature from another connection is rejected")
	auth.expire_challenges()
	check(not auth.verify_response(3, signature), "expired challenge rejected")
	auth.disconnect_peer(1)
	check(auth.get_identity(1).is_empty(), "disconnect removes authenticated identity")
	dispose(auth)


func run():
	test_profile_service()
	test_identity_authentication()
	print("Profile core: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

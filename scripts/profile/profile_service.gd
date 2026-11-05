extends RefCounted

signal profile_changed(owner: String)
signal remote_profiles_changed
const Identity = preload("res://scripts/profile/profile_identity.gd")
var private_key: CryptoKey
var local: Dictionary = {}
var remote: Dictionary = {}
var config_path := "user://profile.cfg"
var last_error := ""
var seen_revisions: Dictionary = {}
var memory_only := false

func configure(key: CryptoKey, path: String):
	private_key = key
	config_path = path
	local = Identity.defaults()
	local.public_key = key.save_to_string(true) if key != null else ""
	local.revision = 0
	remote.clear()
	seen_revisions.clear()
	_sign(local)

func get_local_fingerprint() -> String:
	return Identity.fingerprint(local.get("public_key", ""))

func can_edit(owner: String) -> bool:
	return private_key != null and not private_key.is_public_only() \
		and not owner.is_empty() and owner == get_local_fingerprint()

func get_profile(owner: String) -> Dictionary:
	if not owner.is_empty() and owner == get_local_fingerprint():
		return local.duplicate(true)
	return remote.get(owner, {}).duplicate(true)

func _sign(profile: Dictionary):
	if private_key != null and not private_key.is_public_only() and not profile.public_key.is_empty():
		profile.signature = Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,
			Identity.digest(Identity.signed_bytes(profile.public_key, int(profile.revision), profile)), private_key))

func save_profile(owner: String, fields: Dictionary) -> bool:
	if not can_edit(owner):
		last_error = "Only the private-key owner can edit this profile."
		return false
	var next = Identity.normalized(fields)
	if next.is_empty():
		last_error = "Invalid name, description or media URL. No changes saved."
		return false
	next.public_key = local.public_key
	next.revision = int(local.get("revision", 0)) + 1
	_sign(next)
	if memory_only:
		local = next
		last_error = ""
		profile_changed.emit(owner)
		return true
	var config = ConfigFile.new()
	# Never overwrite corrupt data or an unrelated account's profile.
	if FileAccess.file_exists(config_path):
		if config.load(config_path) != OK or config.get_value("profile", "public_key", "") != local.public_key:
			last_error = "Existing profile is unreadable or belongs to another key; not overwritten."
			return false
		var existing: Dictionary = {}
		for id in config.get_section_keys("profile"):
			existing[id] = config.get_value("profile", id)
		if not Identity.verify_profile(existing):
			last_error = "Existing profile signature is invalid; file preserved for recovery."
			return false
	for id in next:
		config.set_value("profile", id, next[id])
	var error = config.save(config_path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(config_path + ".tmp", config_path)
	if error != OK:
		last_error = "Could not save profile: " + error_string(error)
		return false
	local = next
	last_error = ""
	profile_changed.emit(owner)
	return true

func load_profile() -> bool:
	if not FileAccess.file_exists(config_path):
		return true
	var config = ConfigFile.new()
	if config.load(config_path) != OK:
		last_error = "Profile file could not be read; preserved for recovery."
		return false
	var profile: Dictionary = {}
	for id in config.get_section_keys("profile") if config.has_section("profile") else []:
		profile[id] = config.get_value("profile", id)
	if profile.get("public_key") != local.public_key or not Identity.verify_profile(profile):
		last_error = "Profile key/signature mismatch; file not adopted."
		return false
	local = profile
	profile_changed.emit(get_local_fingerprint())
	return true

func cache_remote_profile(session: String, public_key: String, profile: Dictionary) -> String:
	# Internal adapter: caller has already verified relay session scope/signature.
	var owner = Identity.fingerprint(public_key)
	if session.is_empty() or owner.is_empty() or owner == get_local_fingerprint() \
		or Identity.normalized(profile).is_empty():
		return ""
	var next = profile.duplicate(true)
	next.public_key = Identity.canonical_key(public_key)
	next.session_id = session
	remote[owner] = next
	return owner

func replace_remote_profiles(session: String, profiles: Array):
	var replacement: Dictionary = {}
	for profile in profiles:
		if profile is Dictionary and Identity.verify_profile(profile):
			var owner = Identity.fingerprint(profile.public_key)
			if int(profile.revision) < int(seen_revisions.get(owner, -1)):
				continue
			seen_revisions[owner] = int(profile.revision)
			var next = profile.duplicate(true)
			next.session_id = session
			if owner != get_local_fingerprint():
				replacement[owner] = next
	remote = replacement
	remote_profiles_changed.emit()

func clear_remote_profiles():
	remote.clear()
	seen_revisions.clear()
	remote_profiles_changed.emit()

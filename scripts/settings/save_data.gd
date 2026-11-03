extends Node

var data = {
	"username": "User",
	"avatar_url": "https://raw.githubusercontent.com/V-Sekai/godot-vrm/refs/heads/master/vrm_samples/AliciaSolid_vrm-0.51.vrm",
	"temp_world_file_save_path": "user://wolds/temp.cne",
	"default_avatar": "https://raw.githubusercontent.com/V-Sekai/godot-vrm/refs/heads/master/vrm_samples/AliciaSolid_vrm-0.51.vrm",
	"default_wold": "LocalWold"
}
var key = CryptoKey.new()
var settings_path = "user://user.cfg"
var key_path = "user://user.key"
var registry = preload("res://scripts/settings/settings_registry.gd").new()
var store = preload("res://scripts/settings/settings_store.gd").new()
var voice = preload("res://scripts/player/voice_controller.gd").new()
var profile = preload("res://scripts/profile/profile_service.gd").new()
var friends = preload("res://scripts/profile/friend_service.gd").new()
var account_error := ""
signal account_ready

func _init():
	registry.register_defaults()
	store.configure(registry, settings_path)
	store.setting_changed.connect(_apply_setting)
	voice.configure(store)
	profile.profile_changed.connect(_on_profile_changed)

func _ready():
	if "--relay" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		return # Relay mode must never load client account/settings persistence.
	# Load before either player scene (and therefore microphone) is created.
	laod_data()
	add_child(store)
	add_child(voice)
	for definition in registry.get_definitions():
		_apply_setting(definition.id, store.get_value(definition.id))

func _apply_setting(id: String, value: Variant):
	var definition: Dictionary = registry.get_definition(id)
	if definition.has("legacy_key"):
		data[definition.legacy_key] = value
	var bus_name = {"audio.master_volume": "Master", "audio.voice_volume": "PlayerVoices"}.get(id, "")
	if not bus_name.is_empty():
		var index = AudioServer.get_bus_index(bus_name)
		if index >= 0:
			AudioServer.set_bus_volume_linear(index, float(value) / 100.0)

# laod public key: keypair.save_to_string(true)

func create_acount() -> bool:
	var crypto = Crypto.new()
	key = crypto.generate_rsa(4096)
	if key == null or key.save(key_path) != OK:
		account_error = "Could not create/save account key."
		return false
	print("Acount created")
	return true
	
func load_acount() -> bool:
	print("Loading Acount...")
	if FileAccess.file_exists(key_path):
		if key.load(key_path) != OK or key.is_public_only():
			account_error = "Account key is unreadable. It was not replaced. Restore your key backup."
			return false
		print("Acount Loaded")
	else:
		print("Acount not found creating new...")
		if not create_acount():
			return false
	initialize_profile()
	return true

func initialize_profile(path: String = ""):
	var fingerprint = preload("res://scripts/profile/profile_identity.gd").fingerprint(key.save_to_string(true))
	var directory = "user://profiles"
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var profile_path = path if not path.is_empty() else directory.path_join(fingerprint + ".cfg")
	profile.configure(key, profile_path)
	if FileAccess.file_exists(profile_path):
		profile.load_profile()
	else:
		# Migrate legacy values only for the account whose local key is loaded.
		var fields = preload("res://scripts/profile/profile_identity.gd").defaults()
		fields["profile.username"] = data.username
		fields["profile.avatar_url"] = data.avatar_url
		profile.save_profile(fingerprint, fields)
	_on_profile_changed(fingerprint)
	account_error = profile.last_error
	var friends_path = profile_path.get_base_dir().path_join(fingerprint + "-friends.cfg") if not path.is_empty() else "user://friends/".path_join(fingerprint + ".cfg")
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute("user://friends")
	friends.configure(key, friends_path)
	friends.self_profile = profile.get_profile(fingerprint)
	account_ready.emit()

func _on_profile_changed(owner: String):
	if owner != profile.get_local_fingerprint():
		return
	var fields: Dictionary = profile.get_profile(owner)
	friends.self_profile = fields.duplicate(true)
	data.username = fields.get("profile.username", "User")
	data.avatar_url = fields.get("profile.avatar_url", data.default_avatar)

func save_data() -> bool:
	# Compatibility for existing callers that still edit profile fields directly.
	if profile.can_edit(profile.get_local_fingerprint()):
		var fields: Dictionary = profile.get_profile(profile.get_local_fingerprint())
		fields["profile.username"] = data.username
		fields["profile.avatar_url"] = data.avatar_url
		if not profile.save_profile(profile.get_local_fingerprint(), fields):
			return false
	return store.save_settings()
	
	
func laod_data() -> bool:
	store.config_path = settings_path
	var loaded = store.load_settings()
	for definition in registry.get_definitions():
		_apply_setting(definition.id, store.get_value(definition.id))
	var config = ConfigFile.new()
	if config.load(settings_path) == OK:
		# Read migration sources directly before generic settings saves remove old
		# profile rows. The profile service becomes authoritative after key loading.
		if profile.get_local_fingerprint().is_empty():
			for pair in [["username", "profile.username"], ["avatar_url", "profile.avatar_url"]]:
				var value = config.get_value("settings", pair[1], config.get_value("UserSettings", pair[0], data[pair[0]]))
				if value is String:
					data[pair[0]] = value
		var path = config.get_value("UserSettings", "temp_world_file_save_path", "user://worlds/temp.cne")
		data.temp_world_file_save_path = path if path is String and path.begins_with("user://") else "user://worlds/temp.cne"
		var world = config.get_value("UserSettings", "default_wold", "LocalWold")
		data.default_wold = world if world is String else "LocalWold"
	return loaded

func _notification(what):
	if "--relay" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST and store.dirty:
		store.save_settings()
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(voice) and voice.get_parent() == null:
			voice.free()
		if is_instance_valid(store) and store.get_parent() == null:
			store.free()

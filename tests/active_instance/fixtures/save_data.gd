extends Node

var key: CryptoKey
var profile = preload("res://scripts/profile/profile_service.gd").new()
var data := {"username": "Local test account"}
var registry = preload("res://scripts/settings/settings_registry.gd").new()
var store = preload("res://scripts/settings/settings_store.gd").new()
var friends = preload("res://scripts/profile/friend_service.gd").new()

func _ready():
	registry.register_defaults()
	store.configure(registry, "res://unused-active-settings.cfg")
	add_child(store)
	# Ephemeral private key only: never load/save the user's account or settings.
	key = Crypto.new().generate_rsa(2048)
	profile.configure(key, "res://unused-test-profile.cfg")
	profile.local["profile.username"] = "Alice"
	profile.local["profile.avatar_url"] = "https://avatars.example/alice.vrm"
	profile._sign(profile.local)
	friends.configure(key, "res://isolated-friends.cfg")
	friends.self_profile = profile.local.duplicate(true)

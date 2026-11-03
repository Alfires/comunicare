extends Node
var registry = preload("res://scripts/settings/settings_registry.gd").new()
var store = preload("res://scripts/settings/settings_store.gd").new()
var voice = preload("res://scripts/player/voice_controller.gd").new()
var profile
var friends
var key: CryptoKey
var data = {"avatar_url": "", "username": "VR fixture"}

func _init():
	registry.register_defaults()
	store.configure(registry, "res://settings-fixture.cfg")
	voice.configure(store)

func _exit_tree():
	store.free()
	voice.free()

extends "res://scripts/settings/save_data.gd"

var saves := 0

func _ready():
	# Use the real store/controller/initialization, but only a disposable config.
	settings_path = "res://test-user.cfg"
	data.username = "Test user"
	data.avatar_url = "https://example.test/avatar.vrm"
	store.config_path = settings_path
	store.save_settings()
	super._ready()

func save_data() -> bool:
	saves += 1
	return super.save_data()

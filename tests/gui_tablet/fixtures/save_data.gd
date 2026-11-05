extends "res://scripts/settings/save_data.gd"
## Real registry/store/voice/theme ownership with a disposable config only.

func _ready():
	settings_path = "res://test-user.cfg"
	data.username = "Test user"
	data.avatar_url = "https://example.test/avatar.vrm"
	store.config_path = settings_path
	store.save_settings()
	super._ready()

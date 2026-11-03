extends "res://scripts/settings/save_data.gd"

func _ready():
	# Real initialization/store, but never the actual user config or account key.
	settings_path = "res://profile-test-settings.cfg"
	key_path = "res://never-created.key"
	super._ready()
	key = Crypto.new().generate_rsa(2048)
	initialize_profile("res://local-ui-profile.cfg")

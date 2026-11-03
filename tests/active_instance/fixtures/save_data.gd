extends Node

var key: CryptoKey
var profile = preload("res://scripts/profile/profile_service.gd").new()
var data := {"username": "Local test account"}

func _ready():
	# Ephemeral private key only: never load/save the user's account or settings.
	key = Crypto.new().generate_rsa(2048)
	profile.configure(key, "res://unused-test-profile.cfg")
	profile.local["profile.username"] = "Alice"
	profile.local["profile.avatar_url"] = "https://avatars.example/alice.vrm"
	profile._sign(profile.local)

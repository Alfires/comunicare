extends Node
var key: CryptoKey
var profile = preload("res://scripts/profile/profile_service.gd").new()
var friends
var data = {"username": "Fixture", "avatar_url": "https://example.invalid/self.vrm"}

func _ready():
	key = Crypto.new().generate_rsa(2048)
	profile.configure(key, "res://never-saved-profile.cfg")

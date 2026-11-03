extends Node

var key = CryptoKey.new()
var data = {"username": "Discovery test"}

func _ready():
	key = Crypto.new().generate_rsa(2048)

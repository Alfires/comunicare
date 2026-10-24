extends Node

var data = {
	"plyer_model_url": "https://raw.githubusercontent.com/V-Sekai/godot-vrm/refs/heads/master/vrm_samples/AliciaSolid_vrm-0.51.vrm",
	"temp_world_file_save_path": "user://wolds/temp.cne",
}
var keypair = CryptoKey.new()
var save_path = "user://user.data"
var key_path = "user://user.key"

# laod public key: keypair.save_to_string(true)

func create_acount():
	var crypto = Crypto.new()
	keypair = crypto.generate_rsa(4096)
	keypair.save(key_path)
	print("Acount created")
	
func load_acount():
	print("Loading Acount...")
	if FileAccess.file_exists(key_path):
		keypair.load(key_path)
		print("Acount Loaded")
	else:
		print("Acount not found creating new...")
		create_acount()
	return true
		
func save_data():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	print("Data created")
	
func laod_data():
	print("Loading Data...")
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			data = json.data
			print("Data Loaded")
		else:
			printerr("Data coud not be loaded")
	else:
		print("Data not found creating new..")
		save_data()

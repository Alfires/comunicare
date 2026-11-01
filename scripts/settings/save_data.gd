extends Node

var data = {
	"avatar_url": "https://raw.githubusercontent.com/V-Sekai/godot-vrm/refs/heads/master/vrm_samples/AliciaSolid_vrm-0.51.vrm",
	"temp_world_file_save_path": "user://wolds/temp.cne",
	"default_avatar": "https://raw.githubusercontent.com/V-Sekai/godot-vrm/refs/heads/master/vrm_samples/AliciaSolid_vrm-0.51.vrm",
	"default_wold": "LocalWold"
}
var key = CryptoKey.new()
var settings_path = "user://user.cfg"
var key_path = "user://user.key"

# laod public key: keypair.save_to_string(true)

func create_acount():
	var crypto = Crypto.new()
	key = crypto.generate_rsa(4096)
	key.save(key_path)
	print("Acount created")
	
func load_acount():
	print("Loading Acount...")
	if FileAccess.file_exists(key_path):
		key.load(key_path)
		print("Acount Loaded")
	else:
		print("Acount not found creating new...")
		create_acount()
	return true
		
func save_data():
	print("Saving Data...")
	var config := ConfigFile.new()
	config.load(settings_path)
	
	config.set_value("UserSettings", "username", data["username"])
	config.set_value("UserSettings", "avatar_url", data["avatar_url"])
	config.set_value("UserSettings", "temp_world_file_save_path", data["temp_world_file_save_path"])
	config.set_value("UserSettings","default_wold","LocalWold" )
	print("Data created")
	var error := config.save(settings_path)
	if error != OK:
		push_error("Could not save data: %s" % error_string(error))
	else:
		print("Data Saved")
	
	
func laod_data():
	print("Loading Data...")
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		print("Data not found creating new..")
	data["username"] = config.get_value("UserSettings","username","User")
	data["avatar_url"] = config.get_value("UserSettings","avatar_url","https://raw.githubusercontent.com/V-Sekai/godot-vrm/refs/heads/master/vrm_samples/AliciaSolid_vrm-0.51.vrm")
	data["temp_world_file_save_path"] =  config.get_value("UserSettings","avatar_url","user://wolds/temp.cne")
	config.set_value("UserSettings","default_wold","LocalWold" )
	print("Data Loaded")
	save_data()

extends Node


var desktops: Array = ["Linux","Windows","macOS"]
var player_scene
var config

func _ready():
	if "--relay" in OS.get_cmdline_args(): 
		get_tree().change_scene_to_file("res://scenes/relay.tscn")
	else:
		print("Game starting up...")
		await SaveData.load_acount()
		await SaveData.laod_data()
		NetworkHandler.create_peer()
		NetworkHandler.create_session()
		call_deferred("load_initial_scene")

func load_initial_scene():
	load_player()
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	
func instantiate_player(player):
	var s = ResourceLoader.load(player)
	player_scene = s.instantiate() 

func load_player():
	var VR
	var os = OS.get_name()
	if "--non_vr" not in OS.get_cmdline_args(): 
		VR = XRServer.find_interface("OpenVR")
		VR = XRServer.find_interface("OpenXR")
	if VR and VR.initialize():
		print("OpenXR initialized successfully")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		instantiate_player("res://scenes/player/player_vr.tscn")
	elif os in desktops:
		print("OpenXR not initialized, please check if your headset is connected. error: ")
		print("loading Desktop: ", os)
		instantiate_player("res://scenes/player/player_desktop.tscn")
		
	get_tree().root.add_child.call_deferred(player_scene)

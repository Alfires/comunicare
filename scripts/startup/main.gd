extends Node


var desktops: Array = ["Linux","Windows","macOS"]
var player_scene
var config

func _ready():
	if "--relay" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"): 
		var xr = XRServer.find_interface("OpenXR")
		if xr != null: xr.uninitialize()
		get_viewport().use_xr = false
		get_tree().change_scene_to_file("res://scenes/relay.tscn")
	else:
		print("Game starting up...")
		if not SaveData.load_acount():
			push_error(SaveData.account_error)
			load_initial_scene()
			return
		call_deferred("load_initial_scene")
		# The initial scene owns no awaited networking coroutine: it is replaced
		# immediately. The stable autoload completes initial relay setup instead.
		NetworkHandler.connect_initial_relay()

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
	
	

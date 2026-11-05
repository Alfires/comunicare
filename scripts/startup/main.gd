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
		# Returning home must not reload an already-owned key or mount another
		# player. The root-level player survives every world/startup scene change.
		if not get_tree().get_nodes_in_group("player").is_empty():
			call_deferred("load_initial_scene")
			return
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
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_scene = players[0]
		return
	var os = OS.get_name()
	if _initialize_xr():
		print("OpenXR initialized successfully")
		instantiate_player("res://scenes/player/player_vr.tscn")
	elif os in desktops:
		print("OpenXR not initialized, please check if your headset is connected. error: ")
		print("loading Desktop: ", os)
		instantiate_player("res://scenes/player/player_desktop.tscn")
		
	get_tree().root.add_child.call_deferred(player_scene)

func _initialize_xr() -> bool:
	if "--non_vr" in OS.get_cmdline_args():
		return false
	var xr = XRServer.find_interface("OpenXR")
	if xr == null or not xr.initialize():
		return false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().use_xr = true
	return true

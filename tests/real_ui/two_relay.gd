extends SceneTree
var relay
func _initialize(): call_deferred("run")
func run():
	var arguments = OS.get_cmdline_user_args()
	relay = load("res://scripts/multiplayer/relay.gd").new()
	relay.connection = ENetConnection.new()
	if relay.connection.create_host_bound("127.0.0.1", 0) != OK: quit(2); return
	var file = FileAccess.open(arguments[0], FileAccess.WRITE)
	file.store_string(str(relay.connection.get_local_port()))
	file.close()
func _process(_delta):
	if relay != null: relay.handle_events()
	return false

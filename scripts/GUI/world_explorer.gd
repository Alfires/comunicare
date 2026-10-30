extends Control

@onready var searchbar: LineEdit = $VBoxContainer/HBoxContainer/searchbar
@onready var world_listing: GridContainer = $VBoxContainer/ScrollContainer/CenterContainer/world_listing
@onready var http_request = $HTTPRequest

var worlds_list: = []

signal reset

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)
	var url = "https://github.com/Alfires/comunicare-Officel-World-List/raw/refs/heads/main/worlds.json"
	http_request.request(url)
	NetworkHandler.peer.on_public_session.connect(load_rooms)


func load_rooms():
	$VBoxContainer/ScrollContainer/CenterContainer/world_listing/loading.queue_free()
	for world in worlds_list:
		var world_previewe = Button.new()
		world_previewe.text = world["name"]
		world_previewe.pressed.connect(Callable(self, "create_world_info_menue").bind(world))
		world_listing.add_child(world_previewe)

@warning_ignore("unused_parameter")
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		print("Error: HTTP %d" % response_code)
		return
	
	var json_string = body.get_string_from_utf8()
	var error = JSON.parse_string(json_string)
	if !error: 
		print("coud not load json file")
		return
	worlds_list = error
	load_rooms()


# needs to be changed to load one time on load an not be deleated( add menue in scene)
func create_world_info_menue(world_data):
	var vb = VBoxContainer.new()
	var hb = HBoxContainer.new()
	var back = Button.new()
	var world_name = Label.new()
	var join = Button.new() 
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	join.text = "join"
	join.pressed.connect(Callable(self, "_on_join_pressed").bind(world_data,vb))
	back.text = "<-"
	back.pressed.connect(Callable(self, "close_info_menu").bind(vb))
	reset.connect(Callable(self, "close_info_menu").bind(vb))
	world_name.text = world_data["name"]
	hb.add_child(world_name)
	hb.add_child(join)
	vb.add_child(back)
	vb.add_child(hb)
	add_child(vb)
	$VBoxContainer.hide()
	vb.show()
	
	
func _on_search_pressed() -> void:
	if searchbar.text.begins_with("http"):
		DataLoader.load_world_from_url(searchbar.text)
	else:
		NetworkHandler.join_session(searchbar.text)
	
func _on_join_pressed(world,vb):
	close_info_menu(vb)
	DataLoader.load_world_from_url(world["url"])

func _on_reload_pressed() -> void:
	load_rooms()
	
func close_info_menu(node: Node) -> void:
	deleat_children(node)
	$VBoxContainer.show()

func deleat_children(node: Node):
	for c in node.get_children():
		c.queue_free()
	node.queue_free()

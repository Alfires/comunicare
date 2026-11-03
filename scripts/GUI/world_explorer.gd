extends Control

@onready var searchbar: LineEdit = $VBoxContainer/HBoxContainer/searchbar
@onready var world_listing: GridContainer = $VBoxContainer/ScrollContainer/CenterContainer/world_listing
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var info: VBoxContainer = $WorldInfo
@onready var instance_list: VBoxContainer = $WorldInfo/ScrollContainer/Instances
@onready var status: Label = $Status

# Catalog metadata and relay snapshots must never overwrite one another.
var worlds_list: Array = []
var instances: Dictionary = {}
var worlds_by_url: Dictionary = {}
var selected_url := ""
var discovery_peer: RelayPeer
var refreshing := false
var refresh_started := 0
var last_refresh := 0
var busy := false
signal reset

func _ready() -> void:
	reset.connect(close_info_menu)
	$WorldInfo/Back.pressed.connect(close_info_menu)
	$WorldInfo/Create.pressed.connect(_on_create_pressed)
	http_request.timeout = 15
	http_request.request_completed.connect(_on_request_completed)
	_request_catalog()
	_render_worlds()
	_attach_peer()

func _request_catalog() -> void:
	http_request.request("https://github.com/Alfires/comunicare-Officel-World-List/raw/refs/heads/main/worlds.json")

func _process(_delta: float) -> void:
	if discovery_peer != NetworkHandler.peer:
		_attach_peer()
	if refreshing and Time.get_ticks_msec() - refresh_started > 10000:
		# A request has no correlation ID: don't issue overlapping requests.
		# Clear stale entries, but allow a later reliable response to recover.
		status.text = "Discovery timed out. Waiting for relay response…"
		if get_node_or_null("ErrorPopup") == null or not $ErrorPopup.visible:
			_show_error(status.text)
		instances.clear()
		_render_worlds()
		refresh_started = Time.get_ticks_msec()
	if not refreshing and discovery_peer != null and discovery_peer.is_connected_to_relay \
		and Time.get_ticks_msec() - last_refresh > 15000:
		_on_reload_pressed()

func _attach_peer() -> void:
	if discovery_peer != null:
		for pair in [[discovery_peer.on_public_session, load_sessions],
			[discovery_peer.connected, _on_reload_pressed],
			[discovery_peer.on_disconnected_from_relay, _on_disconnected]]:
			if pair[0].is_connected(pair[1]):
				pair[0].disconnect(pair[1])
	discovery_peer = NetworkHandler.peer
	refreshing = false
	instances.clear()
	_render_worlds()
	if discovery_peer == null:
		status.text = "Relay disconnected"
		return
	discovery_peer.on_public_session.connect(load_sessions)
	discovery_peer.connected.connect(_on_reload_pressed)
	discovery_peer.on_disconnected_from_relay.connect(_on_disconnected)
	if discovery_peer.is_connected_to_relay:
		_on_reload_pressed()
	else:
		status.text = "Connecting to relay…"

func _exit_tree() -> void:
	if discovery_peer == null:
		return
	for pair in [[discovery_peer.on_public_session, load_sessions],
		[discovery_peer.connected, _on_reload_pressed],
		[discovery_peer.on_disconnected_from_relay, _on_disconnected]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])

func _on_disconnected() -> void:
	refreshing = false
	instances.clear()
	status.text = "Relay disconnected"
	_render_worlds()

func load_sessions(sessions: Array) -> void:
	var replacement: Dictionary = {}
	for value in sessions:
		if not value is Dictionary or value.get("mode", -1) != PacketInfo.MODE.PUBLIC:
			continue
		var id = value.get("session_id")
		if not id is String or id.is_empty() or id.length() > 128 \
			or not WorldAddress.is_valid(value.get("world_url")):
			continue
		if replacement.has(id):
			continue
		var count = value.get("player_count", 0)
		if not (count is int or count is float) or not is_finite(float(count)):
			continue
		replacement[id] = {
			"session_id": id, "world_url": value.world_url,
			"name": str(value.get("name", "Public instance")).left(128),
			"description": str(value.get("description", "")).left(2048),
			"player_count": clampi(int(count), 0, 256),
		}
	instances = replacement
	refreshing = false
	last_refresh = Time.get_ticks_msec()
	status.text = ""
	_render_worlds()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status.text = "Catalog unavailable; public discovery still works"
		_show_error(status.text)
		return
	var values = JSON.parse_string(body.get_string_from_utf8())
	if not values is Array:
		status.text = "Invalid world catalog"
		_show_error(status.text)
		return
	worlds_list = values
	_render_worlds()

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _render_worlds() -> void:
	worlds_by_url.clear()
	for world in worlds_list:
		if world is Dictionary and WorldAddress.is_valid(world.get("url")):
			worlds_by_url[world.url] = world.duplicate(true)
	worlds_by_url["default_wold"] = {"url": "default_wold", "name": "Comunicare Home",
		"description": "The default Comunicare home world."}
	for instance in instances.values():
		if not worlds_by_url.has(instance.world_url):
			worlds_by_url[instance.world_url] = {"url": instance.world_url,
				"name": instance.world_url.get_file().get_slice("?", 0),
				"description": instance.world_url}
	_clear(world_listing)
	for world in worlds_by_url.values():
		var preview = Button.new()
		preview.text = str(world.get("name", world.url))
		preview.tooltip_text = world.url
		preview.pressed.connect(create_world_info_menue.bind(world))
		world_listing.add_child(preview)
	if not selected_url.is_empty():
		_render_info()

func create_world_info_menue(world_data: Dictionary) -> void:
	selected_url = world_data.url
	$VBoxContainer.hide()
	info.show()
	_render_info()

func _render_info() -> void:
	_clear(instance_list)
	var world = worlds_by_url.get(selected_url, {"name": selected_url, "description": ""})
	$WorldInfo/Name.text = str(world.get("name", selected_url))
	$WorldInfo/Description.text = str(world.get("description", ""))
	$WorldInfo/Create.disabled = busy
	var ids = instances.keys()
	ids.sort()
	for id in ids:
		var instance: Dictionary = instances[id]
		if instance.world_url != selected_url or id == NetworkHandler.current_session_id:
			continue
		var row = HBoxContainer.new()
		row.set_meta("session_id", id)
		var label = Label.new()
		label.text = "%s — %d players\n%s" % [instance.name, instance.player_count, instance.description]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var join = Button.new()
		join.text = "Join"
		join.disabled = busy
		join.pressed.connect(_join_instance.bind(id))
		row.add_child(join)
		instance_list.add_child(row)
	if instance_list.get_child_count() == 0:
		var empty = Label.new()
		empty.text = "No public instances for this world."
		instance_list.add_child(empty)

func _join_instance(id: String) -> void:
	if busy or not instances.has(id):
		return
	busy = true
	_render_info()
	status.text = "Joining instance…"
	# The network coordinator stages the advertised world and waits for the relay.
	var success: bool = await NetworkHandler.join_session(id, instances[id].world_url)
	if not is_inside_tree():
		return
	busy = false
	status.text = "Joined instance" if success else NetworkHandler.last_session_error
	if not success:
		_show_error(NetworkHandler.last_session_error)
	_render_info()

func _on_create_pressed() -> void:
	if busy or selected_url.is_empty():
		return
	busy = true
	_render_info()
	var success: bool = await NetworkHandler.host_world(selected_url)
	if not is_inside_tree():
		return
	busy = false
	status.text = "Instance created" if success else NetworkHandler.last_session_error
	if not success:
		_show_error(NetworkHandler.last_session_error)
	_render_info()

func _on_search_pressed() -> void:
	var value = searchbar.text.strip_edges()
	if WorldAddress.is_valid(value):
		create_world_info_menue({"url": value})
	elif not busy and not value.is_empty():
		busy = true
		var success: bool = await NetworkHandler.join_session(value)
		if is_inside_tree():
			busy = false
			status.text = "Joined instance" if success else NetworkHandler.last_session_error
			if not success:
				_show_error(NetworkHandler.last_session_error)

func _on_reload_pressed() -> void:
	if refreshing:
		return
	if discovery_peer == null or not discovery_peer.is_connected_to_relay:
		status.text = "Relay disconnected"
		_show_error(status.text)
		return
	refreshing = true
	refresh_started = Time.get_ticks_msec()
	status.text = "Refreshing public instances…"
	GetPublicSessions.create([]).sent(discovery_peer.peer)

func close_info_menu() -> void:
	selected_url = ""
	info.hide()
	$VBoxContainer.show()

func _show_error(message: String):
	preload("res://scripts/GUI/error_popup.gd").show_error(self, message)

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
const Model = preload("res://scripts/discovery/discovery_model.gd")
var discovery_request_id := ""
var discovery_generation := ""
var discovery_sequence := 0
var filter_text := ""
var legacy_timed_out := false
var local_instances: Dictionary = {}
var connecting := false
signal reset
var local_map_picker: FileDialog

func _ready() -> void:
	var edit_local = Button.new()
	edit_local.text = "Edit local project…"
	edit_local.custom_minimum_size.y = 44
	edit_local.pressed.connect(func():
		var editor = load("res://scenes/GUI/map_editor.tscn").instantiate()
		add_child(editor))
	$VBoxContainer/HBoxContainer.add_child(edit_local)
	local_map_picker = FileDialog.new()
	local_map_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	local_map_picker.access = FileDialog.ACCESS_FILESYSTEM
	local_map_picker.use_native_dialog = false
	local_map_picker.filters = PackedStringArray(["*.cworld,*.zip,*.cne ; Validated world package"])
	local_map_picker.file_selected.connect(_load_local_map)
	add_child(local_map_picker)
	var open_local = Button.new()
	open_local.name = "OpenLocalMap"
	open_local.text = "Open local map…"
	open_local.custom_minimum_size.y = 44
	open_local.pressed.connect(func(): local_map_picker.popup_centered_ratio(0.8))
	$VBoxContainer/HBoxContainer.add_child(open_local)
	reset.connect(close_info_menu)
	$WorldInfo/Back.pressed.connect(close_info_menu)
	$WorldInfo/Create.pressed.connect(_on_create_pressed)
	http_request.timeout = 15
	http_request.body_size_limit = 2 * 1024 * 1024
	http_request.max_redirects = 0
	http_request.request_completed.connect(_on_request_completed)
	_request_catalog()
	_render_worlds()
	_attach_peer()
	if NetworkHandler.has_signal("relay_directory_changed"):
		NetworkHandler.relay_directory_changed.connect(_merge_relay_instances)
	if NetworkHandler.has_method("refresh_relay_directories"):
		# Real client startup has a settings owner. Transport-only isolated callers
		# must not create persisted preference state just by opening a browser.
		var save = get_node_or_null("/root/SaveData")
		if save != null and save.get("store") != null: NetworkHandler.refresh_relay_directories()

func _request_catalog() -> void:
	var url = str(ProjectSettings.get_setting("discovery/world_catalog_url", "https://raw.githubusercontent.com/Alfires/comunicare-Officel-World-List/refs/heads/main/worlds.json"))
	if url.is_empty(): return
	if http_request.request(url) != OK:
		status.text = "Catalog request could not start; public discovery still works"

func _load_local_map(path: String):
	if busy: return
	busy = true
	status.text = "Validating local map…"
	var network = get_node("/root/NetworkHandler")
	var loaded = await network.load_local_map(path)
	if not is_inside_tree(): return
	busy = false
	status.text = "Local map loaded offline." if loaded else network.last_session_error

func _process(_delta: float) -> void:
	if discovery_peer != NetworkHandler.peer:
		_attach_peer()
	if refreshing and not connecting and discovery_peer != null and Time.get_ticks_msec() - refresh_started > 10000:
		# A request has no correlation ID: don't issue overlapping requests.
		# Clear stale entries, but allow a later reliable response to recover.
		status.text = "Discovery timed out; retrying public instances…"
		instances.clear()
		local_instances.clear()
		_render_worlds()
		refresh_started = Time.get_ticks_msec()
		if not discovery_peer.directory_supported:
			# Legacy responses cannot correlate retries. Reconnect rather than
			# accepting a late old result as a new snapshot.
			refreshing = false
			legacy_timed_out = true
			status.text = "Legacy directory timed out. Reconnect to retry safely."
		else:
			refreshing = false
			discovery_request_id = ""
			_on_reload_pressed()
	if not refreshing and discovery_peer != null and discovery_peer.is_connected_to_relay \
		and Time.get_ticks_msec() - last_refresh > 15000:
		_on_reload_pressed()

func _attach_peer() -> void:
	if discovery_peer != null:
		if discovery_peer.directory_result.is_connected(receive_directory_result): discovery_peer.directory_result.disconnect(receive_directory_result)
		for pair in [[discovery_peer.on_public_session, load_sessions],
			[discovery_peer.connected, _on_reload_pressed],
			[discovery_peer.on_disconnected_from_relay, _on_disconnected]]:
			if pair[0].is_connected(pair[1]):
				pair[0].disconnect(pair[1])
	discovery_peer = NetworkHandler.peer
	discovery_generation = Crypto.new().generate_random_bytes(16).hex_encode()
	discovery_request_id = ""
	legacy_timed_out = false
	refreshing = false
	instances.clear()
	local_instances.clear()
	_render_worlds()
	if discovery_peer == null:
		status.text = "Relay disconnected"
		return
	discovery_peer.on_public_session.connect(load_sessions)
	discovery_peer.directory_result.connect(receive_directory_result)
	discovery_peer.connected.connect(_on_reload_pressed)
	discovery_peer.on_disconnected_from_relay.connect(_on_disconnected)
	if discovery_peer.is_connected_to_relay:
		_on_reload_pressed()
	else:
		status.text = "Connecting to relay…"

func _exit_tree() -> void:
	if NetworkHandler.has_signal("relay_directory_changed") and NetworkHandler.relay_directory_changed.is_connected(_merge_relay_instances):
		NetworkHandler.relay_directory_changed.disconnect(_merge_relay_instances)
	if discovery_peer == null:
		return
	if discovery_peer.directory_result.is_connected(receive_directory_result): discovery_peer.directory_result.disconnect(receive_directory_result)
	for pair in [[discovery_peer.on_public_session, load_sessions],
		[discovery_peer.connected, _on_reload_pressed],
		[discovery_peer.on_disconnected_from_relay, _on_disconnected]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])

func _on_disconnected() -> void:
	discovery_generation = ""
	discovery_request_id = ""
	refreshing = false
	instances.clear()
	local_instances.clear()
	status.text = "Relay disconnected"
	_render_worlds()

func load_sessions(sessions: Array) -> void:
	local_instances = Model.summaries(sessions)
	_merge_relay_instances()
	refreshing = false
	last_refresh = Time.get_ticks_msec()
	status.text = ""
	_render_worlds()

func _merge_relay_instances():
	instances = local_instances.duplicate(true)
	if NetworkHandler.has_method("get_remote_instances"):
		for summary in NetworkHandler.get_remote_instances():
			var value: Dictionary = summary.duplicate(true)
			var id = summary.origin_relay_id + ":" + summary.origin_boot_id + ":" + summary.instance_id
			value.session_id = id
			value.remote_relay = true
			instances[id] = value
	if is_node_ready(): _render_worlds()

func receive_directory_result(value: Dictionary):
	if not refreshing or discovery_request_id.is_empty() or value.get("request_id") != discovery_request_id or value.get("generation") != discovery_generation: return
	if value.get("version") != 1 or not value.get("sessions") is Array: return
	discovery_request_id = ""
	load_sessions(value.sessions)

func classify_query(text: String) -> String:
	return Model.classify_query(text)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status.text = "Catalog unavailable; public discovery still works"
		return
	var values = Model.catalog(body)
	if not values.ok:
		status.text = "Invalid world catalog"
		return
	worlds_list = values.value
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
		if not filter_text.is_empty() and not filter_text.to_lower() in (str(world.get("name", "")) + " " + str(world.get("description", ""))).to_lower(): continue
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
		if instance.get("remote_relay", false): label.text += "\nFederated relay " + str(instance.origin_relay_id).left(12)
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
	var success: bool
	if instances[id].get("remote_relay", false):
		success = await NetworkHandler.join_remote_instance(instances[id])
	else:
		success = await NetworkHandler.join_session(id, instances[id].world_url)
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
	var intent = classify_query(value)
	if intent == "url":
		create_world_info_menue({"url": value})
	elif intent == "code" and not busy:
		busy = true
		var success: bool = await NetworkHandler.join_session(value)
		if is_inside_tree():
			busy = false
			status.text = "Joined instance" if success else NetworkHandler.last_session_error
			if not success:
				_show_error(NetworkHandler.last_session_error)
	else:
		filter_text = value
		_render_worlds()

func _on_reload_pressed() -> void:
	if legacy_timed_out: return
	if refreshing:
		return
	if discovery_peer == null or not discovery_peer.is_connected_to_relay:
		if NetworkHandler.has_method("ensure_relay_connected"):
			if connecting: return
			connecting = true
			refreshing = true
			refresh_started = Time.get_ticks_msec()
			status.text = "Connecting to relay…"
			var connected_ok: bool = await NetworkHandler.ensure_relay_connected()
			if not is_inside_tree(): return
			connecting = false
			refreshing = false
			_attach_peer()
			if connected_ok:
				_on_reload_pressed()
			else:
				status.text = NetworkHandler.last_session_error
				_show_error(status.text)
			return
		status.text = "Relay disconnected"
		_show_error(status.text)
		return
	refreshing = true
	refresh_started = Time.get_ticks_msec()
	status.text = "Refreshing public instances…"
	if discovery_peer.directory_supported:
		discovery_sequence += 1
		discovery_request_id = str(discovery_sequence)
		GetPublicSessions.directory({"version": 1, "request_id": discovery_request_id, "generation": discovery_generation}).sent(discovery_peer.peer)
	else: GetPublicSessions.create([]).sent(discovery_peer.peer)

func close_info_menu() -> void:
	selected_url = ""
	info.hide()
	$VBoxContainer.show()

func _show_error(message: String):
	preload("res://scripts/GUI/error_popup.gd").show_error(self, message)

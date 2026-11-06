extends Control
var authority = preload("res://scripts/editor/edit_authority.gd").new()
var store = preload("res://scripts/editor/project_store.gd").new()
var text: TextEdit
var status: Label
var picker: FileDialog
var action := ""
var account_owner := ""
var path := ""
var session: Node
var host_field: LineEdit
var port_field: SpinBox
var fingerprint_field: LineEdit
var requests: VBoxContainer
var entities: OptionButton
var coordinates: Array[SpinBox] = []

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("blocks_global_shortcuts", true)
	account_owner = get_node("/root/SaveData").profile.get_local_fingerprint()
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var layout = VBoxContainer.new()
	panel.add_child(layout)
	var title = Label.new()
	title.text = "Local map project editor"
	layout.add_child(title)
	var close = Button.new()
	close.text = "Close editor (save first)"
	close.pressed.connect(queue_free)
	layout.add_child(close)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Separate direct-IP editing. Verify the account_owner's fingerprint; host approves each viewer/editor. Save/export is account_owner-only."
	layout.add_child(status)
	session = preload("res://scripts/editor/edit_session.gd").new()
	add_child(session)
	session.changed.connect(_session_changed)
	session.status_changed.connect(func(message): status.text = message)
	var network_row = HFlowContainer.new()
	layout.add_child(network_row)
	host_field = LineEdit.new()
	host_field.text = "127.0.0.1"
	host_field.placeholder_text = "Host IP / bind address"
	network_row.add_child(host_field)
	port_field = SpinBox.new()
	port_field.min_value = 0
	port_field.max_value = 65535
	port_field.value = 7385
	network_row.add_child(port_field)
	fingerprint_field = LineEdit.new()
	fingerprint_field.placeholder_text = "Owner fingerprint (verify out of band)"
	fingerprint_field.custom_minimum_size.x = 220
	network_row.add_child(fingerprint_field)
	for pair in [["Host editing", _host_session], ["Request access", _join_session], ["Disconnect", func(): session.close(); status.text = "Editing disconnected"]]:
		var button = Button.new()
		button.text = pair[0]
		button.pressed.connect(pair[1])
		network_row.add_child(button)
	requests = VBoxContainer.new()
	layout.add_child(requests)
	var edit_row = HFlowContainer.new()
	layout.add_child(edit_row)
	entities = OptionButton.new()
	edit_row.add_child(entities)
	for axis in ["X", "Y", "Z"]:
		var coordinate = SpinBox.new()
		coordinate.prefix = axis
		coordinate.min_value = -10000
		coordinate.max_value = 10000
		coordinate.step = 0.1
		coordinates.append(coordinate)
		edit_row.add_child(coordinate)
	var move = Button.new()
	move.text = "Move selected entity"
	move.pressed.connect(func():
		if entities.selected < 0: return
		session.move_entity(str(entities.get_selected_metadata()), [coordinates[0].value, coordinates[1].value, coordinates[2].value]))
	edit_row.add_child(move)
	for pair in [["New project", _new], ["Open project…", func(): _choose("open")], ["Save project…", func(): _choose("save")], ["Export playable map…", func(): _choose("export")]]:
		var button = Button.new()
		button.text = pair[0]
		button.custom_minimum_size.y = 44
		button.pressed.connect(pair[1])
		layout.add_child(button)
	text = TextEdit.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.y = 180
	layout.add_child(text)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = false
	picker.file_selected.connect(_selected)
	add_child(picker)
	_new()

func _process(_delta):
	if session.connection != null and get_node("/root/SaveData").profile.get_local_fingerprint() != account_owner:
		session.close()
		status.text = "Account changed; editing disconnected. Close and reopen this panel."

func _new():
	if session != null and session.connection != null:
		status.text = "Disconnect editing before replacing the project."
		return
	var document = {"schema": 1, "world_id": Crypto.new().generate_random_bytes(16).hex_encode(), "title": "Local map", "revision": 0, "entities": [{"id": "spawn", "name": "Spawn", "type": "spawn", "position": [0, 1, 0]}, {"id": "floor", "name": "Floor", "type": "scenery", "position": [0, -0.1, 0], "collider": {"type": "box", "size": [20, 0.2, 20]}}], "assets": [], "behaviors": [], "capabilities": []}
	authority.configure(document, account_owner, Crypto.new().generate_random_bytes(16).hex_encode())
	text.text = JSON.stringify(document, "\t")
	path = ""

func _choose(mode: String):
	action = mode
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE if mode == "open" else FileDialog.FILE_MODE_SAVE_FILE
	picker.filters = PackedStringArray(["*.cworld ; Playable package"]) if mode == "export" else PackedStringArray(["*.json ; Local authoring project"])
	picker.popup_centered_ratio(0.8)

func _selected(selected_path: String):
	if get_node("/root/SaveData").profile.get_local_fingerprint() != account_owner:
		status.text = "Account changed. Close and reopen the editor."
		return
	if action == "open" and session.connection != null:
		status.text = "Disconnect editing before opening another project."
		return
	var result: Dictionary
	if action == "open":
		result = store.load_project(selected_path)
		if result.ok:
			authority.configure(result.document, account_owner, Crypto.new().generate_random_bytes(16).hex_encode())
			text.text = JSON.stringify(result.document, "\t")
			path = selected_path
	else:
		if session.connection != null and not session.hosting:
			status.text = "Only the editing account_owner can save or export the shared project."
			return
		var parsed = {"ok": true, "value": session.document} if session.hosting else preload("res://scripts/worlds/world_text_parser.gd").new().parse_json(text.text)
		if not parsed.ok or not parsed.value is Dictionary:
			status.text = "Invalid project JSON"
			return
		result = preload("res://addons/comunicare_world_tools/world_exporter.gd").new().export_package(parsed.value, selected_path) if action == "export" else store.save_project(parsed.value, selected_path)
	status.text = "Completed: " + selected_path if result.ok else str(result.get("error", "Operation rejected"))

func _host_session():
	var parsed = preload("res://scripts/worlds/world_text_parser.gd").new().parse_json(text.text)
	if not parsed.ok or not parsed.value is Dictionary: status.text = "Invalid project"; return
	if session.host(parsed.value, get_node("/root/SaveData").key, int(port_field.value), host_field.text):
		status.text = "Editing host on UDP %s. Share address and verify fingerprint: %s. Explicit approval required." % [session.connection.get_local_port(), session.owner_fingerprint]
	else: status.text = "Could not host; validate project and choose a free UDP port."

func _join_session():
	if session.join(host_field.text, int(port_field.value), fingerprint_field.text.strip_edges(), get_node("/root/SaveData").key): status.text = "Connecting to editing host…"
	else: status.text = "Invalid address/port/account_owner fingerprint."

func _session_changed():
	text.editable = session.connection == null
	if session.authenticated:
		text.text = JSON.stringify(session.document, "\t")
		entities.clear()
		for entity in session.document.entities:
			entities.add_item(entity.name)
			entities.set_item_metadata(entities.item_count - 1, entity.id)
	for child in requests.get_children():
		requests.remove_child(child)
		child.queue_free()
	if not session.hosting: return
	for request in session.pending.values():
		if not request.get("verified", false): continue
		var fingerprint: String = request.fingerprint
		for access in ["viewer", "editor"]:
			var approve = Button.new()
			approve.text = "Approve %s as %s" % [fingerprint, access]
			approve.pressed.connect(session.approve.bind(fingerprint, access))
			requests.add_child(approve)
	for member in session.members.values():
		var revoke = Button.new()
		revoke.text = "Revoke " + member.fingerprint
		revoke.pressed.connect(session.revoke.bind(member.fingerprint))
		requests.add_child(revoke)

extends Control
var authority = preload("res://scripts/editor/edit_authority.gd").new()
var store = preload("res://scripts/editor/project_store.gd").new()
var text: TextEdit
var status: Label
var picker: FileDialog
var action := ""
var owner := ""
var path := ""

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("blocks_global_shortcuts", true)
	owner = get_node("/root/SaveData").profile.get_local_fingerprint()
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
	status.text = "Local source projects only. Friend editing transport is not implemented; no remote access is granted."
	layout.add_child(status)
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

func _new():
	var document = {"schema": 1, "world_id": Crypto.new().generate_random_bytes(16).hex_encode(), "title": "Local map", "revision": 0, "entities": [{"id": "spawn", "name": "Spawn", "type": "spawn", "position": [0, 1, 0]}, {"id": "floor", "name": "Floor", "type": "scenery", "position": [0, -0.1, 0], "collider": {"type": "box", "size": [20, 0.2, 20]}}], "assets": [], "behaviors": [], "capabilities": []}
	authority.configure(document, owner, Crypto.new().generate_random_bytes(16).hex_encode())
	text.text = JSON.stringify(document, "\t")
	path = ""

func _choose(mode: String):
	action = mode
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE if mode == "open" else FileDialog.FILE_MODE_SAVE_FILE
	picker.filters = PackedStringArray(["*.cworld ; Playable package"]) if mode == "export" else PackedStringArray(["*.json ; Local authoring project"])
	picker.popup_centered_ratio(0.8)

func _selected(selected_path: String):
	if get_node("/root/SaveData").profile.get_local_fingerprint() != owner:
		status.text = "Account changed. Close and reopen the editor."
		return
	var result: Dictionary
	if action == "open":
		result = store.load_project(selected_path)
		if result.ok:
			authority.configure(result.document, owner, Crypto.new().generate_random_bytes(16).hex_encode())
			text.text = JSON.stringify(result.document, "\t")
			path = selected_path
	else:
		var parsed = preload("res://scripts/worlds/world_text_parser.gd").new().parse_json(text.text)
		if not parsed.ok or not parsed.value is Dictionary:
			status.text = "Invalid project JSON"
			return
		result = preload("res://addons/comunicare_world_tools/world_exporter.gd").new().export_package(parsed.value, selected_path) if action == "export" else store.save_project(parsed.value, selected_path)
	status.text = "Completed: " + selected_path if result.ok else str(result.get("error", "Operation rejected"))
